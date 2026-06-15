import Foundation

struct Token: Equatable {
  let value: UUID

  init() {
    value = UUID()
  }
}

final class FeedbackEventConsumer<Event> {
  private let processEvent: (Event, Token) -> Void
  private let dequeueEvents: (Token) -> Void

  init(
    process: @escaping (Event, Token) -> Void,
    dequeueAllEvents: @escaping (Token) -> Void
  ) {
    self.processEvent = process
    self.dequeueEvents = dequeueAllEvents
  }

  func process(_ event: Event, for token: Token) {
    processEvent(event, token)
  }

  func dequeueAllEvents(for token: Token) {
    dequeueEvents(token)
  }
}

extension FeedbackEventConsumer {
  func pullback<LocalEvent>(_ f: @escaping (LocalEvent) -> Event) -> FeedbackEventConsumer<LocalEvent> {
    FeedbackEventConsumer<LocalEvent>(
      process: { event, token in self.process(f(event), for: token) },
      dequeueAllEvents: { token in self.dequeueAllEvents(for: token) }
    )
  }
}
