import Combine

public extension Publishers {
  struct FeedbackLoop<Output, Event, Dependency>: Publisher {
    public typealias Failure = Never
    let initial: Output
    let reduce: Reducer<Output, Event>
    let feedbacks: [Feedback<Output, Event, Dependency>]
    let dependency: Dependency

    public init(
      initial: Output,
      reduce: Reducer<Output, Event>,
      feedbacks: [Feedback<Output, Event, Dependency>],
      dependency: Dependency
    ) {
      self.initial = initial
      self.reduce = reduce
      self.feedbacks = feedbacks
      self.dependency = dependency
    }

    public func receive<S>(subscriber: S) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
      let floodgate = Floodgate<Output, Event, S, Dependency>(
        state: initial,
        feedbacks: feedbacks,
        sink: subscriber,
        reducer: reduce,
        dependency: dependency
      )
      subscriber.receive(subscription: floodgate)
      floodgate.bootstrap()
    }
  }
}
