import CombineFeedbackUI

extension ViewContext {
    static func empty(_ state: State) -> ViewContext {
        ViewContext(state: state, send: { _ in }, mutate: { _ in })
    }
}
    
