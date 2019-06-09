import Combine
import Foundation

enum RequestError: Error {
    case request(code: Int, error: Error?)
    case unknown
}

extension URLSession {
    func send(url: URL) -> Publishers.Future<(data: Data, response: HTTPURLResponse), RequestError> {
        return send(request: URLRequest(url: url))
    }

    func send(request: URLRequest) -> Publishers.Future<(data: Data, response: HTTPURLResponse), RequestError> {
        return Publishers.Future { promise in
            self.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    let httpReponse = response as? HTTPURLResponse
                    if let data = data, let httpReponse = httpReponse, 200..<300 ~= httpReponse.statusCode {
                        promise(Result.success((data, httpReponse)))
                    } else if let httpReponse = httpReponse {
                        promise(.failure(.request(code: httpReponse.statusCode, error: error)))
                    } else {
                        promise(.failure(.unknown))
                    }
                }
            }
            .resume()
        }
    }
}
