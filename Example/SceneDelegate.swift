import UIKit
import SwiftUI
import CombineFeedbackUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let tabbarController = UITabBarController()
        let counter = UIHostingController(
            rootView: NavigationView {
                return Widget(renderer: CounterRenderer(), system: CounterSystem())
                    .navigationBarTitle(Text("Counter"))
            }
        )
        counter.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "eye"),
            selectedImage: UIImage(systemName: "eye.fill")
        )
        let movies = UIHostingController(
            rootView: NavigationView {
                Widget(renderer: MoviesRenderer(), system: MoviesSystem())
                    .navigationBarTitle(Text("Movies"))
            }
        )
        movies.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "film"),
            selectedImage: UIImage(systemName: "film.fill")
        )

        tabbarController.viewControllers = [counter, movies]
        window.rootViewController = tabbarController
        self.window = window
        window.makeKeyAndVisible()
    }
}

