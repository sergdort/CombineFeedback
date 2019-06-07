import UIKit
import SwiftUI
import CombineFeedbackUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let tabbarController = UITabBarController()
        tabbarController.viewControllers = [
            UIHostingController(
                rootView: NavigationView {
                    Widget(renderer: CounterRenderer(), system: CounterSystem())
                        .navigationBarTitle(Text("Counter"))
                }
            ),
            UIHostingController(
                rootView: NavigationView {
                    Widget(renderer: MoviesRenderer(), system: MoviesSystem())
                        .navigationBarTitle(Text("Movies"))
                }
            )
        ]
        window.rootViewController = tabbarController
        self.window = window
        window.makeKeyAndVisible()
    }
}

