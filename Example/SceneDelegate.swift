import CombineFeedbackUI
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let tabbarController = UITabBarController()
        let counter = UIHostingController(
            rootView: NavigationView {
                Widget(viewModel: CounterViewModel(), renderer: CounterRenderer())
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
                Widget(viewModel: MoviesViewModel(), renderer: MoviesRenderer())
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
