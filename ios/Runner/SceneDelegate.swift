import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Cold start: the URL arrives in the connection options.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    connectionOptions.urlContexts.forEach { NativeChannel.shared.open($0.url) }
  }

  // Warm start.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    URLContexts.forEach { NativeChannel.shared.open($0.url) }
  }
}
