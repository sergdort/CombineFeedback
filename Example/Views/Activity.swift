import SwiftUI

struct Activity: UIViewRepresentable {
    typealias UIViewType = UIActivityIndicatorView
    var isAnimating: Binding<Bool>
    let style: UIActivityIndicatorView.Style
    
    func makeUIView(context: UIViewRepresentableContext<Activity>) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.startAnimating()
        return view
    }
    
    public func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<Activity>) {
        isAnimating.wrappedValue ? uiView.startAnimating() : uiView.stopAnimating()
    }
}

#if DEBUG
struct Activity_Previews : PreviewProvider {
    static var previews: some View {
        Activity(isAnimating: .constant(true), style: .medium)
    }
}
#endif
