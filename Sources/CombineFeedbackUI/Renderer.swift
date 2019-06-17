import SwiftUI
import CombineFeedback

public protocol Renderer {
    associatedtype State
    associatedtype Event
    associatedtype Content: View

    func render(context: Context<State, Event>) -> Content
}
