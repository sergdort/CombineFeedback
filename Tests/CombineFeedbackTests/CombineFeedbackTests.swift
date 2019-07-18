import Combine
@testable import CombineFeedback
import XCTest

class CombineFeedbackTests: XCTestCase {
    func test_emits_initial() {
        let initial = "initial"
        var result = [String]()

        let system = Publishers.system(
            initial: initial,
            feedbacks: [],
            scheduler: DispatchQueue.main,
            reduce: { (state: String, event: String) in
                state + event
            }
        )

        _ = system.sink {
            result.append($0)
        }

        XCTAssertEqual(result, ["initial"])
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = Feedback<String, String>(effects: { _ -> AnyPublisher<String, Never> in
            Just("_a").eraseToAnyPublisher()
        })
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback],
            scheduler: DispatchQueue.main,
            reduce: { (state: String, event: String) in
                state + event
            }
        )
        let exp = expectation(description: #function)

        var result: [String] = []

        _ = system.output(in: 0...3)
            .collect()
            .sink {
                dump($0)
                result = $0
                exp.fulfill()
            }

        waitForExpectations(timeout: 1, handler: nil)

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
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback1, feedback2],
            scheduler: DispatchQueue.main,
            reduce: { (state: String, event: String) in
                state + event
            }
        )
        var results: [String] = []

        let exp = expectation(description: #function)

        _ = system.output(in: 0...5).collect().sink {
            results = $0
            exp.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

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
        let exp = expectation(description: #function)
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [
                Feedback(effects: { _ -> AnyPublisher<String, Never> in
                    subject.eraseToAnyPublisher()
                }),
            ],
            scheduler: DispatchQueue.main,
            reduce: { (state: String, event: String) -> String in
                state + event
            }
        )

        var value: String?

        _ = system.sink(
            receiveValue: {
                value = $0
                if $0 == "initial_a" {
                    exp.fulfill()
                }
            }
        )

        XCTAssertEqual("initial", value)

        subject.send("_a")

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual("initial_a", value)
    }
}
