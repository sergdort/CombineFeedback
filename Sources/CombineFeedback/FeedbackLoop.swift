import Combine

extension Publishers {
  struct FeedbackLoop<Output, Event>: Publisher {
    typealias Failure = Never
    let initial: Output
    let reduce: Reducer<Output, Event>
    let feedbacks: [Feedback<Output, Event>]
    let activity: LoopActivity?

    init(
      initial: Output,
      reduce: Reducer<Output, Event>,
      feedbacks: [Feedback<Output, Event>],
      activity: LoopActivity? = nil
    ) {
      self.initial = initial
      self.reduce = reduce
      self.feedbacks = feedbacks
      self.activity = activity
    }

    func receive<S>(subscriber: S) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
      let floodgate = Floodgate<Output, Event, S>(
        state: initial,
        feedbacks: feedbacks,
        sink: subscriber,
        reducer: reduce
      )
      activity?.attach { [weak floodgate] in floodgate?.isIdle ?? true }
      subscriber.receive(subscription: floodgate)
      floodgate.bootstrap()
    }
  }
}
