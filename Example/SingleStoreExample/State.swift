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

let countReducer: Reducer<State, Event> = Counter.reducer()
    .pullback(
        value: \.counter,
        event: /Event.counter
    )

let moviesReducer: Reducer<State, Event> = Movies.reducer()
    .pullback(
        value: \.movies,
        event: /Event.movies
    )

let moviesFeedback: Feedback<State, Event> = Movies.feedback
    .pullback(
        value: \.movies,
        event: Event.movies
    )

let signInReducer: Reducer<State, Event> = SignIn.reducer().pullback(
    value: \.signIn,
    event: /Event.signIn
)

let signInFeedback: Feedback<State, Event> = SignIn.feedback
    .pullback(
        value: \.signIn,
        event: Event.signIn
    )

let traficLightReducer: Reducer<State, Event> = TrafficLight.reducer()
    .pullback(
        value: \.traficLight,
        event: /Event.trafficLight
    )

let trafficLightFeedback: Feedback<State, Event> = TrafficLight.feedback.pullback(
    value: \.traficLight,
    event: Event.trafficLight
)

let appReducer = Reducer.combine(
    countReducer,
    moviesReducer,
    signInReducer,
    traficLightReducer
)
