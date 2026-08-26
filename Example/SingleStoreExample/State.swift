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

  @CasePathable
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
    Scope(
      state: \.counter,
      event: \.counter
    ) {
      Counter()
    }
    Scope(
      state: \.switchExample,
      event: \.switchExample
    ) {
      SwitchStoreExample(
        dependencies: SwitchStoreExample.Dependencies(signIn: dependencies.signIn)
      )
    }
    Scope(
      state: \.favouriteMovies,
      event: \.favouriteMovies
    ) {
      FavouriteMovies(dependencies: dependencies.movies)
    }
    Scope(
      state: \.signIn,
      event: \.signIn
    ) {
      SignIn(dependencies: dependencies.signIn)
    }
    Scope(
      state: \.traficLight,
      event: \.trafficLight
    ) {
      TrafficLight()
    }
  }
}
