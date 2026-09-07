import AuthenticationServices
import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#else
  import Cocoa
  import FlutterMacOS
#endif

/// Runs an OAuth authorization request in `ASWebAuthenticationSession` and
/// returns the callback URL.
///
/// This is the mobile answer to a loopback redirect. A desktop app can bind
/// `127.0.0.1` and have the browser redirect to it (RFC 8252); an iPhone
/// cannot rely on that, so the OS runs the browser and hands the app back a
/// URL on a scheme it registered.
///
/// It is also the better flow where both work: the session shares Safari's
/// cookies, so somebody already signed in to the provider is not asked
/// again, and the OS says which site is asking.
public class AppleWebAuthPlugin: NSObject, FlutterPlugin {
  static let channelName = "org.spectrum3847.apple_web_auth"

  /// Held for the length of the flow. `ASWebAuthenticationSession` is
  /// released as soon as nothing references it, which cancels the sign-in
  /// the moment it starts.
  private var session: ASWebAuthenticationSession?
  private var presentationAnchor: PresentationAnchor?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    registrar.addMethodCallDelegate(AppleWebAuthPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "authenticate" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let raw = args["url"] as? String,
      let url = URL(string: raw),
      let scheme = args["callbackScheme"] as? String, !scheme.isEmpty
    else {
      result(
        FlutterError(
          code: "bad_arguments",
          message: "authenticate needs a url and a callbackScheme.",
          details: nil))
      return
    }

    let anchor = PresentationAnchor()
    let session = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: scheme
    ) { [weak self] callback, error in
      self?.session = nil
      self?.presentationAnchor = nil
      if let callback {
        result(callback.absoluteString)
        return
      }
      // Somebody closing the sheet is the common case and is not a fault, so
      // it gets its own code rather than reading as a failure.
      if let error = error as? ASWebAuthenticationSessionError,
        error.code == .canceledLogin
      {
        result(FlutterError(code: "cancelled", message: "Sign-in was cancelled.", details: nil))
        return
      }
      result(
        FlutterError(
          code: "failed",
          message: error?.localizedDescription ?? "Sign-in failed.",
          details: nil))
    }
    session.presentationContextProvider = anchor
    // Deliberately not ephemeral: sharing Safari's cookies means somebody
    // already signed in to the provider is not made to do it again.
    session.prefersEphemeralWebBrowserSession = false

    self.session = session
    self.presentationAnchor = anchor
    if !session.start() {
      self.session = nil
      self.presentationAnchor = nil
      result(
        FlutterError(
          code: "failed",
          message: "The system would not open a sign-in window.",
          details: nil))
    }
  }
}

/// Tells the system which window to present the sign-in sheet over.
private class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(iOS)
      let scenes = UIApplication.shared.connectedScenes
      for scene in scenes {
        guard let scene = scene as? UIWindowScene else { continue }
        if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
          return window
        }
      }
      return ASPresentationAnchor()
    #else
      return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    #endif
  }
}
