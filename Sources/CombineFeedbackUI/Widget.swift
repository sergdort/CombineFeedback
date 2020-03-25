import Combine
import CombineFeedback
import SwiftUI

public struct Widget<State, Event, Content: View>: View {
    private let store: Store<State, Event>
    private let content: (Context<State, Event>) -> Content

    public init(
        store: Store<State, Event>,
        @ViewBuilder content: @escaping (Context<State, Event>) -> Content
    ) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        return content(store.context)
    }
}
