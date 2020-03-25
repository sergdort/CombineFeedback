import CombineFeedbackUI

extension Context {
    static func empty(_ state: State) -> Context {
        Context(state: state, send: { _ in }, mutate: { _ in })
    }
}
    
