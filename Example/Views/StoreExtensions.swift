import CombineFeedbackUI
import CombineFeedback

extension Store {
    static func empty(_ state: State) -> Store {
      Store(initial: state, feedbacks: [], reducer: .empty, dependency: ())
    }
}

extension Reducer {
  static var empty: Reducer {
    Reducer(reduce: { _, _ in })
  }
}
    
