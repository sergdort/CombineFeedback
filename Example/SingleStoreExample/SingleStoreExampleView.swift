import CombineFeedback
import SwiftUI

struct SingleStoreExampleView: View {
  let store: Store<AppFeature.State, AppFeature.Event>

  init(store: Store<AppFeature.State, AppFeature.Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    TabView {
      NavigationView {
        CounterView(
          store: store.scoped(to: \.counter, event: AppFeature.Event.counter)
        )
        .navigationBarTitle(Text("Counter"))
      }
      .tabItem {
        Image(systemName: "eye")
      }
      NavigationView {
        SwitchStoreExampleView(
          store: store.scoped(to: \.switchExample, event: AppFeature.Event.switchExample)
        )
          .navigationBarTitle(Text("Switch Store"))
      }
      .tabItem {
        Image(systemName: "switch.2")
      }
      NavigationView {
        FavouriteMoviesView(
          store: store.scoped(to: \.favouriteMovies, event: AppFeature.Event.favouriteMovies)
        )
        .navigationBarTitle(Text("Parent Child State"))
      }
      .tabItem {
        Image(systemName: "film")
      }
      NavigationView {
        SignInView(store: store.scoped(to: \.signIn, event: AppFeature.Event.signIn))
          .navigationBarTitle(Text("Form Example"))
      }
      .tabItem {
        Image(systemName: "person")
      }
      NavigationView {
        TrafficLightView(store: store.scoped(to: \.traficLight, event: AppFeature.Event.trafficLight))
          .navigationBarTitle(Text("Non UI Effects"))
      }
      .tabItem {
        Image(systemName: "tortoise")
      }
    }
  }
}
