import Combine

extension Publishers {
    public struct FeedbackLoop<Output, Event>: Publisher {
        public typealias Failure = Never
        let initial: Output
        let reduce: Reducer<Output, Event>
        let feedbacks: [Feedback<Output, Event>]

        public init(
            initial: Output,
            reduce: Reducer<Output, Event>,
            feedbacks: [Feedback<Output, Event>]
        ) {
            self.initial = initial
            self.reduce = reduce
            self.feedbacks = feedbacks
        }

        public func receive<S>(subscriber: S) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
            let floodgate = Floodgate<Output, Event, S>(
                state: initial,
                feedbacks: feedbacks,
                sink: subscriber,
                reducer: reduce
            )
            subscriber.receive(subscription: floodgate)
            floodgate.bootstrap()
        }
    }
}
