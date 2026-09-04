import Foundation

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
final class ControlledAsyncSequence<Element: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private let stream: AsyncStream<Element>
  private let continuation: AsyncStream<Element>.Continuation
  private var iteratorCount = 0
  private var iteratorWaiters: [CheckedContinuation<Void, Never>] = []
  private var nextCallCount = 0
  private var nextCallWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private var isTerminated = false
  private var terminationWaiters: [CheckedContinuation<Void, Never>] = []

  init() {
    var continuation: AsyncStream<Element>.Continuation!
    stream = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
    self.continuation = continuation
    continuation.onTermination = { [weak self] _ in
      self?.didTerminate()
    }
  }

  var sequence: Sequence {
    Sequence(source: self)
  }

  var numberOfIterators: Int {
    lock.lock()
    defer { lock.unlock() }
    return iteratorCount
  }

  func yield(_ element: Element) {
    continuation.yield(element)
  }

  func finish() {
    continuation.finish()
  }

  func waitForIterator() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if iteratorCount > 0 {
        lock.unlock()
        continuation.resume()
      } else {
        iteratorWaiters.append(continuation)
        lock.unlock()
      }
    }
  }

  func waitForNextCall(_ call: Int) async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if nextCallCount >= call {
        lock.unlock()
        continuation.resume()
      } else {
        nextCallWaiters.append((call, continuation))
        lock.unlock()
      }
    }
  }

  func waitForTermination() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if isTerminated {
        lock.unlock()
        continuation.resume()
      } else {
        terminationWaiters.append(continuation)
        lock.unlock()
      }
    }
  }

  private func recordIterator() {
    lock.lock()
    iteratorCount += 1
    let waiters = iteratorWaiters
    iteratorWaiters = []
    lock.unlock()

    for waiter in waiters {
      waiter.resume()
    }
  }

  private func recordNextCall() {
    lock.lock()
    nextCallCount += 1
    let waiters = nextCallWaiters.filter { $0.0 <= nextCallCount }
    nextCallWaiters.removeAll { $0.0 <= nextCallCount }
    lock.unlock()

    for (_, waiter) in waiters {
      waiter.resume()
    }
  }

  private func didTerminate() {
    lock.lock()
    guard !isTerminated else {
      lock.unlock()
      return
    }
    isTerminated = true
    let waiters = terminationWaiters
    terminationWaiters = []
    lock.unlock()

    for waiter in waiters {
      waiter.resume()
    }
  }

  struct Sequence: AsyncSequence {
    typealias Failure = Never

    fileprivate let source: ControlledAsyncSequence

    func makeAsyncIterator() -> Iterator {
      source.recordIterator()
      return Iterator(source: source, iterator: source.stream.makeAsyncIterator())
    }

    struct Iterator: AsyncIteratorProtocol {
      private let source: ControlledAsyncSequence
      private let box: IteratorBox

      fileprivate init(source: ControlledAsyncSequence, iterator: AsyncStream<Element>.Iterator) {
        self.source = source
        box = IteratorBox(iterator: iterator)
      }

      mutating func next() async -> Element? {
        source.recordNextCall()
        return await box.next()
      }
    }

    private final class IteratorBox: @unchecked Sendable {
      private var iterator: AsyncStream<Element>.Iterator

      init(iterator: AsyncStream<Element>.Iterator) {
        self.iterator = iterator
      }

      func next() async -> Element? {
        await iterator.next()
      }
    }
  }
}
