import CombineFeedback
import CombineFeedbackUI
import SwiftUI

struct SingleStoreExampleView: View {
    let context: ViewContext<State, Event>

    init(context: ViewContext<State, Event>) {
        self.context = context
        logInit(of: self)
    }

    var body: some View {
        logBody(of: self)
        return TabView {
            NavigationView {
                CounterView(context: context.view(value: \.counter, event: Event.counter))
                    .navigationBarTitle(Text("Counter"))
            }
            .tabItem {
                Image(systemName: "eye")
            }
            NavigationView {
                MoviesView(context: context.view(value: \.movies, event: Event.movies))
                    .navigationBarTitle(Text("Movies"))
            }
            .tabItem {
                Image(systemName: "film")
            }
            NavigationView {
                SignInView(context: context.view(value: \.signIn, event: Event.signIn))
                    .navigationBarTitle(Text("Sign In"))
            }
            .tabItem {
                Image(systemName: "person")
            }
            NavigationView {
                TrafficLightView(context: context.view(value: \.traficLight, event: Event.trafficLight))
                    .navigationBarTitle(Text("Traffic Light"))
            }
            .tabItem {
                Image(systemName: "tortoise")
            }
        }
    }
}
