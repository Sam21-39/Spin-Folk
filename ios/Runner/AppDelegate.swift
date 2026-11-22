import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.applicationRegistrar
    let messenger = registrar.messenger()
    NativeChannel.shared.attach(messenger: messenger)
    registrar.register(PickerFactory(messenger: messenger), withId: "spinfolk/picker")
    registrar.register(ActionBarFactory(messenger: messenger), withId: "spinfolk/actionbar")
  }
}
