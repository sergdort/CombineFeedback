import Combine
import CombineFeedback
import CasePaths
import Foundation

struct State {
  var counter = Counter.State()
  var switchExample = SwitchStoreExample.State.signIn(SignIn.State())
  var movies = Movies.State(batch: .empty(), movies: [], status: .loading)
  var signIn = SignIn.State()
  var traficLight = TrafficLight.State.red
}

enum Event {
  case switchExample(SwitchStoreExample.Event)
  case counter(Counter.Event)
  case movies(Movies.Event)
  case signIn(SignIn.Event)
  case trafficLight(TrafficLight.Event)
}

let countReducer: Reducer<State, Event> = Counter.reducer()
  .pullback(
    value: \.counter,
    event: /Event.counter
  )

let switchStoreReducer: Reducer<State, Event> = SwitchStoreExample.reducer
  .pullback(
    value: \.switchExample,
    event: /Event.switchExample
  )

let switchStoreFeedback: Feedback<State, Event, AppDependency> = SwitchStoreExample.feedbacks
  .pullback(
    value: \.switchExample,
    event: /Event.switchExample) {
      SwitchStoreExample.Dependencies(signIn: $0.signIn)
    }

let moviesReducer: Reducer<State, Event> = Movies.reducer()
  .pullback(
    value: \.movies,
    event: /Event.movies
  )

let moviesFeedback: Feedback<State, Event, AppDependency> = Movies.feedback
  .pullback(
    value: \.movies,
    event: /Event.movies,
    dependency: \.movies
  )

let signInReducer: Reducer<State, Event> = SignIn.reducer().pullback(
  value: \.signIn,
  event: /Event.signIn
)

let signInFeedback: Feedback<State, Event, AppDependency> = SignIn.feedback
  .pullback(
    value: \.signIn,
    event: /Event.signIn,
    dependency: \.signIn
  )

let traficLightReducer: Reducer<State, Event> = TrafficLight.reducer()
  .pullback(
    value: \.traficLight,
    event: /Event.trafficLight
  )

let trafficLightFeedback: Feedback<State, Event, AppDependency> = TrafficLight.feedback.pullback(
  value: \.traficLight,
  event: /Event.trafficLight,
  dependency: { _ in }
)

let appReducer = Reducer.combine(
  countReducer,
  switchStoreReducer,
  moviesReducer,
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
