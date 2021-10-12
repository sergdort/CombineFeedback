import CombineFeedback
import SwiftUI

struct SingleStoreExampleView: View {
  let store: Store<State, Event>

  init(store: Store<State, Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    TabView {
      NavigationView {
        CounterView(
          store: store.scoped(to: \.counter, event: Event.counter)
        )
        .navigationBarTitle(Text("Counter"))
      }
      .tabItem {
        Image(systemName: "eye")
      }
      NavigationView {
        SwitchStoreExample.RootView(
          store: store.scoped(to: \.switchExample, event: Event.switchExample)
        )
          .navigationBarTitle(Text("Switch Store"))
      }
      .tabItem {
        Image(systemName: "switch.2")
      }
      NavigationView {
        MoviesView(store: store.scoped(to: \.movies, event: Event.movies))
          .navigationBarTitle(Text("Pagination Example"))
      }
      .tabItem {
        Image(systemName: "film")
      }
      NavigationView {
        SignInView(store: store.scoped(to: \.signIn, event: Event.signIn))
          .navigationBarTitle(Text("Form Example"))
      }
      .tabItem {
        Image(systemName: "person")
      }
      NavigationView {
        TrafficLightView(store: store.scoped(to: \.traficLight, event: Event.trafficLight))
          .navigationBarTitle(Text("Non UI Effects"))
      }
      .tabItem {
        Image(systemName: "tortoise")
      }
    }
  }
}
