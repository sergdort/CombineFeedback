import UIKit
import SwiftUI
import CombineFeedbackUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(
            rootView: Widget(renderer: CounterRenderer(), system: CounterSystem())
        )
        self.window = window
        window.makeKeyAndVisible()
    }
}

