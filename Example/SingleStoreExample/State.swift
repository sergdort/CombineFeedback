import Combine
import CombineFeedback
import CombineFeedbackUI
import Foundation

struct State: Builder {
    var counter = Counter.State()
    var movies = Movies.State(batch: .empty(), movies: [], status: .loading)
    var signIn = SignIn.State()
    var traficLight = TrafficLight.State.red
}

enum Event {
    case counter(Counter.Event)
    case movies(Movies.Event)
    case signIn(SignIn.Event)
    case traficLight(TrafficLight.Event)

    var counter: Counter.Event? {
        get {
            guard case let .counter(value) = self else { return nil }
            return value
        }
        set {
            guard case .counter = self, let newValue = newValue else { return }
            self = .counter(newValue)
        }
    }

    var movies: Movies.Event? {
        get {
            guard case let .movies(value) = self else { return nil }
            return value
        }
        set {
            guard case .movies = self, let newValue = newValue else { return }
            self = .movies(newValue)
        }
    }

    var signIn: SignIn.Event? {
        get {
            guard case let .signIn(value) = self else { return nil }
            return value
        }
        set {
            guard case .signIn = self, let newValue = newValue else { return }
            self = .signIn(newValue)
        }
    }

    var traficLight: TrafficLight.Event? {
        get {
            guard case let .traficLight(value) = self else { return nil }
            return value
        }
        set {
            guard case .traficLight = self, let newValue = newValue else { return }
            self = .traficLight(newValue)
        }
    }
}

let countReducer: Reducer<State, Event> = pullback(
    Counter.reducer,
    value: \.counter,
    event: \.counter
)

let moviesReducer: Reducer<State, Event> = pullback(
    Movies.reducer,
    value: \.movies,
    event: \.movies
)

let moviesFeedback: Feedback<State, Event> = Feedback.pullback(
    feedback: Movies.feedback,
    value: \.movies,
    event: Event.movies
)

let signInReducer: Reducer<State, Event> = pullback(
    SignIn.reducer,
    value: \.signIn,
    event: \.signIn
)

let signInFeedback: Feedback<State, Event> = Feedback.pullback(
    feedback: SignIn.feedback,
    value: \.signIn,
    event: Event.signIn
)

let traficLightReducer: Reducer<State, Event> = pullback(
    TrafficLight.reducer,
    value: \.traficLight,
    event: \.traficLight
)

let traficLightFeedback = Feedback<State, Event>.pullback(
    feedback: TrafficLight.feedback,
    value: \.traficLight,
    event: Event.traficLight
)

let appReducer = combine(
    countReducer,
    moviesReducer,
    signInReducer,
    traficLightReducer
)

