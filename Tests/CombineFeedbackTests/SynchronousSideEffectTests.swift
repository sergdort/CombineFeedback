import Combine
import CombineFeedback
import Foundation
import Testing

struct SynchronousSideEffectTests {
  @Test func receivesPostReductionStateInOrderBeforeSequentialSendReturns() {
    var calls: [Call] = []
    let thread = Thread.current
    let store = Store(initial: [Int](), machine: Machine {
      Reducer<[Int], Int> { $0.append($1) }
      SideEffect<[Int], Int>(synchronous: { state, event in
        #expect(Thread.current === thread)
        calls.append(Call(state: state, event: event))
      })
    })

    #expect(calls == [])
    store.send(event: 1)
    #expect(calls == [Call(state: [1], event: 1)])
    #expect(store.state == [1])
    store.send(event: 2)
    #expect(calls == [Call(state: [1], event: 1), Call(state: [1, 2], event: 2)])
    #expect(store.state == [1, 2])
  }

  @Test func reentrantSendIsQueuedUntilCurrentEffectReturns() {
    var calls: [Call] = []
    var trace: [String] = []
    weak var target: Store<[Int], Int>?
    let store = Store(initial: [Int](), machine: Machine {
      Reducer<[Int], Int> { $0.append($1) }
      SideEffect<[Int], Int>(synchronous: { state, event in
        trace.append("begin \(event)")
        calls.append(Call(state: state, event: event))
        if event == 1 {
          target?.send(event: 2)
          #expect(calls == [Call(state: [1], event: 1)])
          #expect(target?.state == [1])
          trace.append("nested send returned")
        }
        trace.append("end \(event)")
      })
    })
    target = store

    store.send(event: 1)

    #expect(trace == ["begin 1", "nested send returned", "end 1", "begin 2", "end 2"])
    #expect(calls == [Call(state: [1], event: 1), Call(state: [1, 2], event: 2)])
    #expect(store.state == [1, 2])
  }

  @Test func cancellationPreventsLaterInvocations() {
    let input = PassthroughSubject<Int, Never>()
    var calls: [Call] = []
    var states: [[Int]] = []
    let subscription = Publishers.system(initial: [Int](), machine: Machine {
      Reducer<[Int], Int> { $0.append($1) }
      Feedback<[Int], Int>.custom { _, output in input.enqueue(to: output) }
      SideEffect<[Int], Int>(synchronous: { state, event in
        calls.append(Call(state: state, event: event))
      })
    }).sink { states.append($0) }

    input.send(1)
    #expect(calls == [Call(state: [1], event: 1)])
    subscription.cancel()
    input.send(2)

    #expect(calls == [Call(state: [1], event: 1)])
    #expect(states == [[], [1]])
  }

  @Test func unlabeledAsyncInitializerStillRuns() async {
    let (stream, continuation) = AsyncStream<Call>.makeStream()
    let store = Store(initial: [Int](), machine: Machine {
      Reducer<[Int], Int> { $0.append($1) }
      SideEffect<[Int], Int> { state, event in
        await record(Call(state: state, event: event), to: continuation)
      }
    })
    store.send(event: 1)
    var iterator = stream.makeAsyncIterator()
    let call = await iterator.next()
    #expect(call == Call(state: [1], event: 1))
    withExtendedLifetime(store) {}
    continuation.finish()
  }
}

private struct Call: Equatable {
  let state: [Int]
  let event: Int
}

private func record(_ call: Call, to continuation: AsyncStream<Call>.Continuation) async {
  continuation.yield(call)
}
