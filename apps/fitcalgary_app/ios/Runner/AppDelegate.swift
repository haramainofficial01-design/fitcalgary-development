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
    if let material = engineBridge.pluginRegistry.registrar(forPlugin: "FitCalgaryNavigation") {
      material.register(FitNavigationFactory(messenger: material.messenger()), withId: "fitcalgary/navigation")
      let channel = FlutterMethodChannel(name: "fitcalgary/material", binaryMessenger: material.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "supportsNativeNavigation" else { result(FlutterMethodNotImplemented); return }
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
      }
    }
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

private final class FitNavigationFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    FitNavigationView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

// Material and controls share a native hierarchy to avoid sampling Flutter's
// painted controls into their own backdrop. Routing remains owned by Dart.
private final class FitNavigationView: NSObject, FlutterPlatformView {
  private let root = UIView()
  private let material = UIVisualEffectView()
  private let channel: FlutterMethodChannel
  private var buttons: [UIButton] = []
  private var selected = 0
  private let accent = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.94, green: 0.54, blue: 0.47, alpha: 1)
      : UIColor(red: 0.65, green: 0.26, blue: 0.21, alpha: 1)
  }

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "fitcalgary/navigation/\(id)", binaryMessenger: messenger)
    super.init()
    selected = (arguments as? [String: Any])?["selectedIndex"] as? Int ?? 0
    root.frame = frame
    material.frame = root.bounds
    material.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    material.layer.cornerRadius = 28
    material.clipsToBounds = true
    root.addSubview(material)
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 2
    stack.translatesAutoresizingMaskIntoConstraints = false
    material.contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 6),
      stack.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -6),
      stack.topAnchor.constraint(equalTo: material.contentView.topAnchor, constant: 4),
      stack.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor, constant: -4)
    ])
    let titles = ["Home", "Gyms", "Board", "Compete", "Me"]
    let symbols = ["house", "square.grid.2x2", "chart.bar", "calendar", "person"]
    for index in titles.indices {
      let button = UIButton(type: .system)
      var configuration = UIButton.Configuration.plain()
      configuration.title = titles[index]
      configuration.image = UIImage(systemName: symbols[index], withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .medium))
      configuration.imagePlacement = .top
      configuration.imagePadding = 3
      configuration.cornerStyle = .capsule
      configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 1, bottom: 4, trailing: 1)
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = UIFont.preferredFont(forTextStyle: .caption2)
        return outgoing
      }
      button.configuration = configuration
      button.titleLabel?.adjustsFontForContentSizeCategory = true
      button.titleLabel?.numberOfLines = 2
      button.tag = index
      button.accessibilityLabel = titles[index]
      button.addTarget(self, action: #selector(selectTab(_:)), for: .touchUpInside)
      buttons.append(button)
      stack.addArrangedSubview(button)
    }
    updateSelection()
    updateMaterial()
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial), name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateSizing), name: UIContentSizeCategory.didChangeNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "preferredHeight" {
        result(self?.preferredHeight ?? 68)
        return
      }
      guard call.method == "setSelectedIndex", let index = call.arguments as? Int, (0..<5).contains(index) else { result(FlutterMethodNotImplemented); return }
      self?.selected = index
      self?.updateSelection()
      result(nil)
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }
  func view() -> UIView { root }

  private var preferredHeight: CGFloat {
    max(68, 48 + UIFont.preferredFont(forTextStyle: .caption2).lineHeight * 2)
  }

  @objc private func updateSizing() {
    updateSelection()
    channel.invokeMethod("heightChanged", arguments: preferredHeight)
  }

  @objc private func updateMaterial() {
    if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
      material.effect = nil
      material.backgroundColor = .systemBackground
    } else if #available(iOS 26.0, *) {
      material.backgroundColor = .clear
      material.effect = UIGlassEffect(style: .regular)
    } else {
      material.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  private func updateSelection() {
    for button in buttons {
      var configuration = button.configuration
      configuration?.baseForegroundColor = button.tag == selected ? accent : .label
      configuration?.background.backgroundColor = button.tag == selected ? accent.withAlphaComponent(0.13) : .clear
      button.configuration = configuration
      button.accessibilityTraits = button.tag == selected ? [.button, .selected] : .button
    }
  }

  @objc private func selectTab(_ sender: UIButton) {
    if sender.tag != selected && !UIAccessibility.isReduceMotionEnabled { UISelectionFeedbackGenerator().selectionChanged() }
    selected = sender.tag
    updateSelection()
    channel.invokeMethod("select", arguments: selected)
  }
}
