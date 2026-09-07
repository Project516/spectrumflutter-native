import Flutter
import UIKit

/// Exposes iOS 26's `UIGlassEffect` to Flutter as a platform view.
///
/// A `UIVisualEffectView` samples whatever sits behind it in the UIKit view
/// hierarchy. Under hybrid composition that backdrop is the Flutter overlay
/// layer holding the content painted below this view, which is what makes a
/// glass surface over Flutter content possible at all.
public class LiquidGlassPlugin: NSObject, FlutterPlugin {
  static let viewType = "org.spectrum3847.liquid_glass/view"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "liquid_glass",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiquidGlassPlugin(), channel: channel)
    registrar.register(LiquidGlassViewFactory(), withId: viewType)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "systemVersion":
      result(UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return LiquidGlassPlatformView(
      frame: frame,
      args: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A single glass surface. Configured once at creation: a platform view is not
/// rebuilt when the Dart widget rebuilds, so the Dart side changes the widget
/// key to force a new one rather than mutating this.
class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let effectView = UIVisualEffectView()

  init(frame: CGRect, args: [String: Any]) {
    super.init()

    let radius = args["cornerRadius"] as? Double ?? 0
    let interactive = args["interactive"] as? Bool ?? false
    let tintArgb = args["tintArgb"] as? Int

    effectView.frame = frame

    // Glass is decoration, so by default it must not swallow the taps meant
    // for the Flutter controls drawn on top of it. Asking for interactive
    // glass opts into the native view taking touches instead.
    effectView.isUserInteractionEnabled = interactive

    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect()
      glass.isInteractive = interactive
      if let tintArgb = tintArgb {
        glass.tintColor = UIColor(argb: tintArgb)
      }
      effectView.effect = glass
      // UIGlassEffect ignores layer.cornerRadius. iOS 26 routes the shape
      // through cornerConfiguration, and a glass view left on the default
      // configuration renders square no matter what the layer says.
      effectView.cornerConfiguration = .corners(
        radius: UICornerRadius(floatLiteral: radius))
    } else {
      // Pre-26 fallback, so the plugin is inert rather than broken. This is a
      // system blur, not Liquid Glass.
      effectView.effect = UIBlurEffect(style: .systemThinMaterial)
      effectView.clipsToBounds = true
      effectView.layer.cornerRadius = radius
      effectView.layer.cornerCurve = .continuous
    }
  }

  func view() -> UIView {
    return effectView
  }
}

extension UIColor {
  /// Decodes a Flutter `Color.toARGB32()` value, which is 0xAARRGGBB.
  convenience init(argb: Int) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255.0,
      green: CGFloat((argb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(argb & 0xFF) / 255.0,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255.0)
  }
}
