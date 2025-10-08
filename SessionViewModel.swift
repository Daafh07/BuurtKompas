import Combine   // <- heel belangrijk
import Foundation

final class SessionViewModel: ObservableObject {
    // tijdelijk: simpele published-flag om te bewijzen dat alles compileert
    @Published var isReady: Bool = true
}
