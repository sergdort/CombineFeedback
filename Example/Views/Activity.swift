import SwiftUI

struct Spinner: UIViewRepresentable {
    typealias UIViewType = UIActivityIndicatorView
    
    var style: UIActivityIndicatorView.Style
    
    func makeUIView(context: UIViewRepresentableContext<Spinner>) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.startAnimating()
        return view
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<Spinner>) {}
}

#if DEBUG
struct Activity_Previews : PreviewProvider {
    static var previews: some View {
        Spinner(style: .medium)
    }
}
#endif
