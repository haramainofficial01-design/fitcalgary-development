import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  private var watchChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FitCalgaryWatchBridge") else { return }
    let channel = FlutterMethodChannel(name: "fitcalgary/watch", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard WCSession.isSupported() else { result(nil); return }
      do {
        switch call.method {
        case "syncAuth":
          guard let arguments = call.arguments as? [String: Any], let token = arguments["accessToken"] as? String, let apiURL = arguments["apiURL"] as? String else { result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing watch authentication context", details: nil)); return }
          try WCSession.default.updateApplicationContext(["accessToken": token, "apiURL": apiURL])
          result(nil)
        case "logout":
          try WCSession.default.updateApplicationContext(["logout": true])
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "WATCH_SYNC_FAILED", message: error.localizedDescription, details: nil)) }
    }
    watchChannel = channel
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
