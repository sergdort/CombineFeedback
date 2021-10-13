import Combine
import CombineFeedback
import CasePaths
import Foundation

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

let countReducer: Reducer<State, Event> = Counter.reducer()
  .pullback(
    state: \.counter,
    event: /Event.counter
  )

let switchStoreReducer: Reducer<State, Event> = SwitchStoreExample.reducer
  .pullback(
    state: \.switchExample,
    event: /Event.switchExample
  )

let switchStoreFeedback: Feedback<State, Event, AppDependency> = SwitchStoreExample.feedbacks
  .pullback(
    state: \.switchExample,
    event: /Event.switchExample) {
      SwitchStoreExample.Dependencies(signIn: $0.signIn)
    }

let favouriteMoviesReducer: Reducer<State, Event> = FavouriteMovies.reducer
  .pullback(
    state: \State.favouriteMovies,
    event: /Event.favouriteMovies
  )

let moviesFeedback = Movies.feedback
  .pullback(
    state: \FavouriteMovies.State.moviesState,
    event: /FavouriteMovies.Event.movies,
    dependency: { (globalDependency: AppDependency) -> Movies.Dependencies in
      globalDependency.movies
    }
  )
  .pullback(
    state: \State.favouriteMovies,
    event: /Event.favouriteMovies,
    dependency: { $0 }
  )

let signInReducer: Reducer<State, Event> = SignIn.reducer().pullback(
  state: \.signIn,
  event: /Event.signIn
)

let signInFeedback: Feedback<State, Event, AppDependency> = SignIn.feedback
  .pullback(
    state: \.signIn,
    event: /Event.signIn,
    dependency: \.signIn
  )

let traficLightReducer: Reducer<State, Event> = TrafficLight.reducer()
  .pullback(
    state: \.traficLight,
    event: /Event.trafficLight
  )

let trafficLightFeedback: Feedback<State, Event, AppDependency> = TrafficLight.feedback.pullback(
  state: \.traficLight,
  event: /Event.trafficLight,
  dependency: { _ in }
)

let appReducer = Reducer.combine(
  countReducer,
  switchStoreReducer,
  favouriteMoviesReducer,
  signInReducer,
  traficLightReducer
)

struct AppDependency {
  let urlSession = URLSession.shared
  let api = GithubAPI()

  var movies: Movies.Dependencies {
    .init(
      movies: urlSession.movies(page:),
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
