import SwiftUI

func logInit<T>(of object: T) {
    print("Init of", type(of: object))
}

func logBody<T: View>(of view: T) {
    print("Body of", type(of: view))
}
