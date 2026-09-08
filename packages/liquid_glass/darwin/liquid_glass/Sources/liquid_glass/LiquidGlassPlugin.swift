import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
#endif

/// Exposes Apple's Liquid Glass to Flutter as a platform view: `UIGlassEffect`
/// on iOS 26 and `NSGlassEffectView` on macOS 26.
///
/// A glass view samples whatever sits behind it in the native view hierarchy.
/// Under Flutter's platform view compositing that backdrop is the layer holding
/// the content painted below this view, which is what makes a glass surface
/// over Flutter content possible at all.
public class LiquidGlassPlugin: NSObject, FlutterPlugin {
  static let viewType = "org.spectrum3847.liquid_glass/view"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "liquid_glass", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(LiquidGlassPlugin(), channel: channel)
    registrar.register(LiquidGlassViewFactory(), withId: viewType)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(iOS 26.0, macOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "systemVersion":
      #if os(iOS)
        result(UIDevice.current.systemVersion)
      #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        result("\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Creation parameters, decoded once. A platform view is not rebuilt when the
/// Dart widget rebuilds, so the Dart side changes the widget key to force a
/// new one rather than mutating these.
struct GlassArgs {
  let radius: Double
  let interactive: Bool
  let tintArgb: Int?

  init(_ args: Any?) {
    let dict = args as? [String: Any] ?? [:]
    radius = dict["cornerRadius"] as? Double ?? 0
    interactive = dict["interactive"] as? Bool ?? false
    tintArgb = dict["tintArgb"] as? Int
  }

  /// Splits a Flutter `Color.toARGB32()` value, which is 0xAARRGGBB.
  var tintComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    guard let argb = tintArgb else { return nil }
    return (
      CGFloat((argb >> 16) & 0xFF) / 255.0,
      CGFloat((argb >> 8) & 0xFF) / 255.0,
      CGFloat(argb & 0xFF) / 255.0,
      CGFloat((argb >> 24) & 0xFF) / 255.0
    )
  }
}

#if os(iOS)

  class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      return LiquidGlassPlatformView(frame: frame, args: GlassArgs(args))
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      return FlutterStandardMessageCodec.sharedInstance()
    }
  }

  /// A single glass surface.
  class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
    private let effectView = UIVisualEffectView()

    init(frame: CGRect, args: GlassArgs) {
      super.init()
      effectView.frame = frame

      // Glass is decoration, so by default it must not swallow the taps meant
      // for the Flutter controls drawn on top of it. Asking for interactive
      // glass opts into the native view taking touches instead.
      effectView.isUserInteractionEnabled = args.interactive

      if #available(iOS 26.0, *) {
        let glass = UIGlassEffect()
        glass.isInteractive = args.interactive
        if let t = args.tintComponents {
          glass.tintColor = UIColor(red: t.r, green: t.g, blue: t.b, alpha: t.a)
        }
        effectView.effect = glass
        // UIGlassEffect ignores layer.cornerRadius. iOS 26 routes the shape
        // through cornerConfiguration, and a glass view left on the default
        // configuration renders square no matter what the layer says.
        effectView.cornerConfiguration = .corners(
          radius: UICornerRadius(floatLiteral: args.radius))
      } else {
        // Pre-26 fallback, so the plugin is inert rather than broken. This is
        // a system blur, not Liquid Glass.
        effectView.effect = UIBlurEffect(style: .systemThinMaterial)
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = args.radius
        effectView.layer.cornerCurve = .continuous
      }
    }

    func view() -> UIView {
      return effectView
    }
  }

#elseif os(macOS)

  class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      let glassArgs = GlassArgs(args)
      if #available(macOS 26.0, *) {
        return GlassView(args: glassArgs)
      }
      return BlurView(args: glassArgs)
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      return FlutterStandardMessageCodec.sharedInstance()
    }
  }

  /// The macOS 26 material. `hitTest` returns nil unless the glass was asked to
  /// be interactive, so clicks on the Flutter controls drawn over it reach the
  /// Flutter view underneath rather than stopping at this one.
  @available(macOS 26.0, *)
  class GlassView: NSGlassEffectView {
    private let interactive: Bool

    init(args: GlassArgs) {
      interactive = args.interactive
      super.init(frame: .zero)
      cornerRadius = args.radius
      if let t = args.tintComponents {
        tintColor = NSColor(red: t.r, green: t.g, blue: t.b, alpha: t.a)
      }
    }

    required init?(coder: NSCoder) {
      interactive = false
      super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      return interactive ? super.hitTest(point) : nil
    }
  }

  /// Pre-26 fallback: a within-window system blur, not Liquid Glass.
  class BlurView: NSVisualEffectView {
    private let interactive: Bool

    init(args: GlassArgs) {
      interactive = args.interactive
      super.init(frame: .zero)
      blendingMode = .withinWindow
      material = .popover
      state = .active
      wantsLayer = true
      layer?.cornerRadius = args.radius
      layer?.cornerCurve = .continuous
      layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
      interactive = false
      super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      return interactive ? super.hitTest(point) : nil
    }
  }

#endif
