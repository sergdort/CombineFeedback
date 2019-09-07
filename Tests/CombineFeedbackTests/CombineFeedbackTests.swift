import Combine
@testable import CombineFeedback
import XCTest

class CombineFeedbackTests: XCTestCase {
    func test_emits_initial() {
        let initial = "initial"
        var result = [String]()

        let scheduler = TestScheduler()
        let system = Publishers.system(
            initial: initial,
            feedbacks: [],
            scheduler: scheduler,
            reduce: { (state: String, event: String) in
                state + event
            }
        )

        _ = system.sink {
            result.append($0)
        }

        scheduler.advance()

        XCTAssertEqual(result, ["initial"])
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = Feedback<String, String>(effects: { _ -> AnyPublisher<String, Never> in
            Just("_a").eraseToAnyPublisher()
        })
        let scheduler = TestScheduler()
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback],
            scheduler: scheduler,
            reduce: { (state: String, event: String) in
                state + event
            }
        )

        var result: [String] = []

        _ = system.output(in: 0...3)
            .collect()
            .sink {
                dump($0)
                result = $0
            }

        scheduler.run()

        let expected = [
            "initial",
            "initial_a",
            "initial_a_a",
            "initial_a_a_a",
        ]
        XCTAssertEqual(result, expected)
    }

    func test_reduce_with_two_immediate_feedback_loops() {
        let feedback1 = Feedback<String, String>(effects: { _ in
            Just("_a")
        })
        let feedback2 = Feedback<String, String>(effects: { _ in
            Just("_b")
        })
        let scheduler = TestScheduler()
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback1, feedback2],
            scheduler: scheduler,
            reduce: { (state: String, event: String) in
                state + event
            }
        )
        var results: [String] = []

        _ = system.output(in: 0...5).collect().sink {
            results = $0
        }

        scheduler.run()

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_a",
            "initial_a_b_a_b",
            "initial_a_b_a_b_a",
        ]

        XCTAssertEqual(results, expected)
    }

    func test_should_observe_signals_immediately() {
        let subject = PassthroughSubject<String, Never>()
        let scheduler = TestScheduler()
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [
                Feedback(effects: { _ -> AnyPublisher<String, Never> in
                    subject.eraseToAnyPublisher()
                }),
            ],
            scheduler: scheduler,
            reduce: { (state: String, event: String) -> String in
                state + event
            }
        )

        var value: String?

        _ = system.sink(
            receiveValue: {
                value = $0
            }
        )

        scheduler.advance()
        XCTAssertEqual("initial", value)

        subject.send("_a")
        scheduler.advance()

        XCTAssertEqual("initial_a", value)
    }
  
    func test_system_in_a_system() {
        let scheduler = TestScheduler()
      
        let feedback1 = Feedback<String, String>(effects: { state -> AnyPublisher<String, Never> in
          if state.count % 3 == 1 {
              return Just("a").eraseToAnyPublisher()
          } else {
              return Empty<String,Never>().eraseToAnyPublisher()
          }
        })
        
        let feedback2 = Feedback<String, String>(effects: { state -> AnyPublisher<String, Never> in
          if state.count % 3 == 0 {
              return Just("d").eraseToAnyPublisher()
          } else {
              return Empty<String,Never>().eraseToAnyPublisher()
          }
        })
      
        let innerSystem = Feedback<String, String>{ (stringPublisher: AnyPublisher<String, Never>) ->  AnyPublisher<String, Never> in
            return stringPublisher.flatMap { (string) -> AnyPublisher<String, Never> in
                return Publishers.system(initial: string,
                                         feedbacks: [feedback1, feedback2],
                                         scheduler: scheduler) { (state: String, event: String) -> String in
                                                return state + event
                }.filter({ (state) -> Bool in
                    state.count % 2 == 0
                }).map({ (state) -> String in
                    return state + "c"
                }).eraseToAnyPublisher()
            }.eraseToAnyPublisher()
        }
      
        let outerSystem = Publishers.system(
            initial: "initial",
            feedbacks: [innerSystem],
            scheduler: scheduler,
            reduce: { (state: String, event: String) -> String in
                return event
            }
        )

        var value: String?

        _ = outerSystem.sink(
            receiveValue: {
                value = $0
            }
        )

        scheduler.advance()
        XCTAssertEqual("initialacdc", value)
    }
}
