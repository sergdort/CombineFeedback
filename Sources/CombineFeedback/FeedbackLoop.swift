import Combine

extension Publishers {
  struct FeedbackLoop<Output, Event>: Publisher {
    typealias Failure = Never
    let initial: Output
    let reduce: Reducer<Output, Event>
    let feedbacks: [Feedback<Output, Event>]
    let drainsOnMainThread: Bool

    init(
      initial: Output,
      reduce: Reducer<Output, Event>,
      feedbacks: [Feedback<Output, Event>],
      drainsOnMainThread: Bool
    ) {
      self.initial = initial
      self.reduce = reduce
      self.feedbacks = feedbacks
      self.drainsOnMainThread = drainsOnMainThread
    }

    func receive<S>(subscriber: S) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
      let floodgate = Floodgate<Output, Event, S>(
        state: initial,
        feedbacks: feedbacks,
        sink: subscriber,
        reducer: reduce,
        drainsOnMainThread: drainsOnMainThread
      )
      subscriber.receive(subscription: floodgate)
      floodgate.bootstrap()
    }
  }
}
