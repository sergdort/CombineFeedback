import CombineFeedback
import CasePaths
import Foundation

struct AppFeature: StateMachine {
  let dependencies: Dependencies

  struct State {
    var counter = Counter.State()
    var switchExample = SwitchStoreExample.State.signIn(SignIn.State())
    var favouriteMovies = FavouriteMovies.State()
    var signIn = SignIn.State()
    var traficLight = TrafficLight.State.red
  }

  enum Event {
    case switchExample(SwitchStoreExample.Event)
    case counter(Counter.Event)
    case favouriteMovies(FavouriteMovies.Event)
    case signIn(SignIn.Event)
    case trafficLight(TrafficLight.Event)
  }

  struct Dependencies {
    let urlSession = URLSession.shared
    let api = GithubAPI()

    var movies: Movies.Dependencies {
      .init(
        fetchMovies: urlSession.fetchMovies(page:)
      )
    }

    var signIn: SignIn.Dependencies {
      .init(
        signIn: api.signIn,
        usernameAvailable: api.usernameAvailable(username:)
      )
    }
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Scope<State, Event, Machine<Counter.State, Counter.Event>>(
      state: \State.counter,
      event: /Event.counter
    ) {
      Counter()
    }
    Scope<State, Event, Machine<SwitchStoreExample.State, SwitchStoreExample.Event>>(
      state: \State.switchExample,
      event: /Event.switchExample
    ) {
      SwitchStoreExample(
        dependencies: SwitchStoreExample.Dependencies(signIn: dependencies.signIn)
      )
    }
    Scope<State, Event, Machine<FavouriteMovies.State, FavouriteMovies.Event>>(
      state: \State.favouriteMovies,
      event: /Event.favouriteMovies
    ) {
      FavouriteMovies(dependencies: dependencies.movies)
    }
    Scope<State, Event, Machine<SignIn.State, SignIn.Event>>(
      state: \State.signIn,
      event: /Event.signIn
    ) {
      SignIn(dependencies: dependencies.signIn)
    }
    Scope<State, Event, Machine<TrafficLight.State, TrafficLight.Event>>(
      state: \State.traficLight,
      event: /Event.trafficLight
    ) {
      TrafficLight()
    }
  }
}
