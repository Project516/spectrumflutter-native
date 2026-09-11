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
///
/// Two view types are registered. The single view is one surface in its own
/// platform view. The group view is a container that draws several surfaces in
/// one native layer, so they share a sampling pass and merge when they come
/// close, which two separate platform views can never do.
public class LiquidGlassPlugin: NSObject, FlutterPlugin {
  static let viewType = "org.spectrum3847.liquid_glass/view"
  static let groupViewType = "org.spectrum3847.liquid_glass/group"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "liquid_glass", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(LiquidGlassPlugin(), channel: channel)
    registrar.register(LiquidGlassViewFactory(), withId: viewType)
    registrar.register(
      LiquidGlassGroupViewFactory(messenger: messenger), withId: groupViewType)
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

/// Splits a Flutter `Color.toARGB32()` value, which is 0xAARRGGBB.
func glassTintComponents(_ argb: Int?) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
  guard let argb = argb else { return nil }
  return (
    CGFloat((argb >> 16) & 0xFF) / 255.0,
    CGFloat((argb >> 8) & 0xFF) / 255.0,
    CGFloat(argb & 0xFF) / 255.0,
    CGFloat((argb >> 24) & 0xFF) / 255.0
  )
}

/// Creation parameters, decoded once. A platform view is not rebuilt when the
/// Dart widget rebuilds, so the Dart side changes the widget key to force a
/// new one rather than mutating these.
struct GlassArgs {
  let radius: Double
  let interactive: Bool
  let tintArgb: Int?
  /// "light", "dark", or nil to follow the system appearance.
  let brightness: String?

  init(_ args: Any?) {
    let dict = args as? [String: Any] ?? [:]
    radius = dict["cornerRadius"] as? Double ?? 0
    interactive = dict["interactive"] as? Bool ?? false
    tintArgb = dict["tintArgb"] as? Int
    brightness = dict["brightness"] as? String
  }

  var tintComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    return glassTintComponents(tintArgb)
  }
}

/// One shape inside a group, in the group's own coordinates with the origin at
/// its top left. Unlike `GlassArgs` these arrive over a method channel and are
/// re-sent whenever a member moves or resizes.
struct GlassShapeSpec {
  let frame: CGRect
  let radius: CGFloat
  let interactive: Bool
  let tintArgb: Int?

  init(_ dict: [String: Any]) {
    frame = CGRect(
      x: dict["x"] as? Double ?? 0,
      y: dict["y"] as? Double ?? 0,
      width: dict["width"] as? Double ?? 0,
      height: dict["height"] as? Double ?? 0
    )
    radius = CGFloat(dict["cornerRadius"] as? Double ?? 0)
    interactive = dict["interactive"] as? Bool ?? false
    tintArgb = dict["tintArgb"] as? Int
  }

  var tintComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    return glassTintComponents(tintArgb)
  }

  static func list(_ raw: Any?) -> [GlassShapeSpec] {
    return (raw as? [[String: Any]] ?? []).map(GlassShapeSpec.init)
  }
}

#if os(macOS)

  /// Left nil this follows the system appearance, same as before. Forcing it
  /// decouples the material from a system appearance the app's own theme has
  /// diverged from.
  func applyBrightness(_ brightness: String?, to view: NSView) {
    switch brightness {
    case "light": view.appearance = NSAppearance(named: .aqua)
    case "dark": view.appearance = NSAppearance(named: .darkAqua)
    default: view.appearance = nil
    }
  }

#endif

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

      // Left nil this follows the system trait collection, same as before.
      // Forcing it decouples the material from a system appearance the app's
      // own theme has diverged from.
      switch args.brightness {
      case "light": effectView.overrideUserInterfaceStyle = .light
      case "dark": effectView.overrideUserInterfaceStyle = .dark
      default: break
      }

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

  class LiquidGlassGroupViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
      self.messenger = messenger
      super.init()
    }

    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      return LiquidGlassGroupPlatformView(
        frame: frame, viewId: viewId, args: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      return FlutterStandardMessageCodec.sharedInstance()
    }
  }

  /// The container. Its shapes arrive after creation and change as the Flutter
  /// widgets they mirror move, so unlike the single view this one keeps a
  /// method channel open for its whole life.
  class LiquidGlassGroupPlatformView: NSObject, FlutterPlatformView {
    private let container: GlassGroupView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
      let dict = args as? [String: Any] ?? [:]
      container = GlassGroupView(
        frame: frame, spacing: CGFloat(dict["spacing"] as? Double ?? 0))
      channel = FlutterMethodChannel(
        name: "liquid_glass/group_\(viewId)", binaryMessenger: messenger)
      super.init()
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "setShapes":
          let dict = call.arguments as? [String: Any] ?? [:]
          if let spacing = dict["spacing"] as? Double {
            self.container.spacing = CGFloat(spacing)
          }
          self.container.apply(shapes: GlassShapeSpec.list(dict["shapes"]))
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    func view() -> UIView {
      return container
    }
  }

  /// Several glass shapes in one native layer.
  ///
  /// On iOS 26 the shapes are `UIGlassEffect` views inside a
  /// `UIGlassContainerEffect` view, which is what makes two of them blend
  /// into one another as they come within `spacing`. Below 26 they are plain
  /// blurs in a plain container and merge into nothing.
  class GlassGroupView: UIView {
    /// Holds the shape views. On 26 this is the container effect view, so the
    /// shapes land in its `contentView`; below 26 it is a plain passthrough.
    private let host: UIVisualEffectView
    private var shapeViews: [UIVisualEffectView] = []
    private var interactiveFrames: [CGRect] = []

    var spacing: CGFloat {
      didSet {
        guard spacing != oldValue else { return }
        applySpacing()
      }
    }

    init(frame: CGRect, spacing: CGFloat) {
      self.spacing = spacing
      host = UIVisualEffectView()
      super.init(frame: frame)
      backgroundColor = .clear
      host.frame = bounds
      host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      addSubview(host)
      applySpacing()
    }

    required init?(coder: NSCoder) {
      spacing = 0
      host = UIVisualEffectView()
      super.init(coder: coder)
    }

    private func applySpacing() {
      if #available(iOS 26.0, *) {
        let effect = UIGlassContainerEffect()
        effect.spacing = spacing
        host.effect = effect
      }
    }

    /// Rebuilds the shape views to match `shapes`.
    ///
    /// When the count is unchanged this only moves the existing views, inside
    /// an animation, so the merge and the separation are the system's own
    /// blend rather than a jump. A change in count adds or removes views, and
    /// animating that would fly a new shape in from wherever the reused view
    /// happened to be.
    func apply(shapes: [GlassShapeSpec]) {
      let reusing = shapes.count == shapeViews.count
      while shapeViews.count > shapes.count {
        shapeViews.removeLast().removeFromSuperview()
      }
      while shapeViews.count < shapes.count {
        let view = UIVisualEffectView()
        host.contentView.addSubview(view)
        shapeViews.append(view)
      }

      interactiveFrames = shapes.filter { $0.interactive }.map { $0.frame }
      isUserInteractionEnabled = !interactiveFrames.isEmpty

      let update = {
        for (view, shape) in zip(self.shapeViews, shapes) {
          self.configure(view, with: shape)
        }
      }
      if reusing {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
          update()
        }
      } else {
        update()
      }
    }

    private func configure(_ view: UIVisualEffectView, with shape: GlassShapeSpec) {
      view.frame = shape.frame
      view.isUserInteractionEnabled = shape.interactive
      if #available(iOS 26.0, *) {
        let glass = UIGlassEffect()
        glass.isInteractive = shape.interactive
        if let t = shape.tintComponents {
          glass.tintColor = UIColor(red: t.r, green: t.g, blue: t.b, alpha: t.a)
        }
        view.effect = glass
        view.cornerConfiguration = .corners(
          radius: UICornerRadius(floatLiteral: Double(shape.radius)))
      } else {
        view.effect = UIBlurEffect(style: .systemThinMaterial)
        view.clipsToBounds = true
        view.layer.cornerRadius = shape.radius
        view.layer.cornerCurve = .continuous
      }
    }

    /// The container spans everything the group covers, most of which is not
    /// glass at all, so it takes a touch only where an interactive shape is.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      for frame in interactiveFrames where frame.contains(point) {
        return super.hitTest(point, with: event)
      }
      return nil
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
      applyBrightness(args.brightness, to: self)
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
      applyBrightness(args.brightness, to: self)
    }

    required init?(coder: NSCoder) {
      interactive = false
      super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      return interactive ? super.hitTest(point) : nil
    }
  }

  class LiquidGlassGroupViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
      self.messenger = messenger
      super.init()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      let dict = args as? [String: Any] ?? [:]
      return GlassGroupNSView(
        spacing: CGFloat(dict["spacing"] as? Double ?? 0),
        channel: FlutterMethodChannel(
          name: "liquid_glass/group_\(viewId)", binaryMessenger: messenger))
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      return FlutterStandardMessageCodec.sharedInstance()
    }
  }

  /// AppKit puts the origin at the bottom left. Flutter's rects are top left,
  /// so the views that host shape frames are flipped rather than every frame
  /// being converted.
  class FlippedView: NSView {
    override var isFlipped: Bool { return true }
  }

  /// Several glass shapes in one native layer.
  ///
  /// On macOS 26 `NSGlassEffectContainerView` groups the `NSGlassEffectView`s
  /// inside its content view, so shapes within `spacing` of each other blend.
  /// Below 26 the same shapes are `NSVisualEffectView` blurs that never merge.
  class GlassGroupNSView: FlippedView {
    private let content = FlippedView()
    private var shapeViews: [NSView] = []
    private var interactiveFrames: [CGRect] = []
    private var containerView: NSView?
    private var spacing: CGFloat

    init(spacing: CGFloat, channel: FlutterMethodChannel) {
      self.spacing = spacing
      super.init(frame: .zero)
      wantsLayer = true

      let host: NSView
      if #available(macOS 26.0, *) {
        let container = NSGlassEffectContainerView()
        container.spacing = spacing
        container.contentView = content
        host = container
      } else {
        host = content
      }
      containerView = host
      host.autoresizingMask = [.width, .height]
      addSubview(host)

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "setShapes":
          let dict = call.arguments as? [String: Any] ?? [:]
          if let spacing = dict["spacing"] as? Double {
            self.setSpacing(CGFloat(spacing))
          }
          self.apply(shapes: GlassShapeSpec.list(dict["shapes"]))
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    required init?(coder: NSCoder) {
      spacing = 0
      super.init(coder: coder)
    }

    override func layout() {
      super.layout()
      containerView?.frame = bounds
      // The container owns its content view's frame on 26, but below 26 the
      // content view is the host itself and autoresizing already covers it.
      if #available(macOS 26.0, *) {
        content.frame = CGRect(origin: .zero, size: bounds.size)
      }
    }

    private func setSpacing(_ value: CGFloat) {
      guard value != spacing else { return }
      spacing = value
      if #available(macOS 26.0, *) {
        (containerView as? NSGlassEffectContainerView)?.spacing = value
      }
    }

    /// Rebuilds the shape views to match `shapes`. Frame changes at an
    /// unchanged count animate, so a merge is the system's blend rather than a
    /// jump; adding or removing a shape does not, since a reused view would
    /// fly in from wherever it last was.
    func apply(shapes: [GlassShapeSpec]) {
      let reusing = shapes.count == shapeViews.count
      while shapeViews.count > shapes.count {
        shapeViews.removeLast().removeFromSuperview()
      }
      while shapeViews.count < shapes.count {
        let view: NSView
        if #available(macOS 26.0, *) {
          view = NSGlassEffectView()
        } else {
          let blur = NSVisualEffectView()
          blur.blendingMode = .withinWindow
          blur.material = .popover
          blur.state = .active
          blur.wantsLayer = true
          view = blur
        }
        content.addSubview(view)
        shapeViews.append(view)
      }

      interactiveFrames = shapes.filter { $0.interactive }.map { $0.frame }

      if reusing {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.allowsImplicitAnimation = true
          for (view, shape) in zip(shapeViews, shapes) {
            configure(view, with: shape)
          }
        }
      } else {
        for (view, shape) in zip(shapeViews, shapes) {
          configure(view, with: shape)
        }
      }
    }

    private func configure(_ view: NSView, with shape: GlassShapeSpec) {
      view.frame = shape.frame
      let tint = shape.tintComponents.map {
        NSColor(red: $0.r, green: $0.g, blue: $0.b, alpha: $0.a)
      }
      if #available(macOS 26.0, *), let glass = view as? NSGlassEffectView {
        glass.cornerRadius = Double(shape.radius)
        glass.tintColor = tint
      } else {
        view.wantsLayer = true
        view.layer?.cornerRadius = shape.radius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
      }
    }

    /// Same rule as the single view: a group is decoration spanning far more
    /// than its shapes, so it takes a click only over an interactive shape.
    override func hitTest(_ point: NSPoint) -> NSView? {
      let local = convert(point, from: superview)
      for frame in interactiveFrames where frame.contains(local) {
        return super.hitTest(point)
      }
      return nil
    }
  }

#endif
