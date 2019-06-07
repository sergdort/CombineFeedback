import CombineFeedback

public protocol System {
    associatedtype State
    associatedtype Event

    var initial: State { get }
    var feedbacks: [Feedback<State, Event>] { get }

    func reducer(state: State, event: Event) -> State
}
