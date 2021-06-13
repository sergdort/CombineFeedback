import CombineFeedbackUI
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = makeSingleStoreExample()
    self.window = window
    window.makeKeyAndVisible()
  }

  private func makeSingleStoreExample() -> UIViewController {
    return UIHostingController(
      rootView: SingleStoreExampleView(
        store: Store(
          initial: State(),
          feedbacks: [
            moviesFeedback,
            signInFeedback,
            trafficLightFeedback
          ],
          reducer: appReducer
        )
      )
    )
  }

  private func makeMultiStoreExample() -> UIViewController {
    let tabbarController = UITabBarController()

    let counter = UIHostingController(
      rootView: NavigationView {
        CounterView(store: Counter.ViewModel())
      }
    )

    counter.tabBarItem = UITabBarItem(
      title: nil,
      image: UIImage(systemName: "eye"),
      selectedImage: UIImage(systemName: "eye.fill")
    )

    let movies = UIHostingController(
      rootView: NavigationView {
        MoviesView(store: Movies.ViewModel())
          .navigationBarTitle(Text("Movies"))
      }
    )

    movies.tabBarItem = UITabBarItem(
      title: nil,
      image: UIImage(systemName: "film"),
      selectedImage: UIImage(systemName: "film.fill")
    )

    let signIn = UIHostingController(
      rootView: NavigationView {
        SignInView(store: SignIn.ViewModel())
          .navigationBarTitle(Text("Sign In"))
      }
    )

    signIn.tabBarItem = UITabBarItem(
      title: nil,
      image: UIImage(systemName: "person"),
      selectedImage: UIImage(systemName: "person.fill")
    )

    let trafficLight = UIHostingController(
      rootView: NavigationView {
        TrafficLightView(store: TrafficLight.ViewModel())
          .navigationBarTitle(Text("Traffic Light"))
      }
    )

    trafficLight.tabBarItem = UITabBarItem(
      title: nil,
      image: UIImage(systemName: "tortoise"),
      selectedImage: UIImage(systemName: "tortoise.fill")
    )

    tabbarController.viewControllers = [counter, movies, signIn, trafficLight]

    return tabbarController
  }
}
