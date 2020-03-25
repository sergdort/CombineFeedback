import Combine
import CombineFeedback
import CombineFeedbackUI
import Foundation
import CasePaths

struct State {
    var counter = Counter.State()
    var movies = Movies.State(batch: .empty(), movies: [], status: .loading)
    var signIn = SignIn.State()
    var traficLight = TrafficLight.State.red
}

enum Event {
    case counter(Counter.Event)
    case movies(Movies.Event)
    case signIn(SignIn.Event)
    case trafficLight(TrafficLight.Event)
}

let countReducer: Reducer<State, Event> = pullback(
    Counter.reducer,
    value: \.counter,
    event: /Event.counter
)

let moviesReducer: Reducer<State, Event> = pullback(
    Movies.reducer,
    value: \.movies,
    event: /Event.movies
)

let moviesFeedback: Feedback<State, Event> = Feedback.pullback(
    feedback: Movies.feedback,
    value: \.movies,
    event: Event.movies
)

let signInReducer: Reducer<State, Event> = pullback(
    SignIn.reducer,
    value: \.signIn,
    event: /Event.signIn
)

let signInFeedback: Feedback<State, Event> = Feedback.pullback(
    feedback: SignIn.feedback,
    value: \.signIn,
    event: Event.signIn
)

let traficLightReducer: Reducer<State, Event> = pullback(
    TrafficLight.reducer,
    value: \.traficLight,
    event: /Event.trafficLight
)

let trafficLightFeedback = Feedback<State, Event>.pullback(
    feedback: TrafficLight.feedback,
    value: \.traficLight,
    event: Event.trafficLight
)

let appReducer = combine(
    countReducer,
    moviesReducer,
    signInReducer,
    traficLightReducer
)

