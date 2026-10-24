import Foundation
import Network
import Combine

/// Live network reachability used by offline mode and the connection banner.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.hengzm.mappro.network")

    /// Read-only stream of reachability changes.
    var onlinePublisher: AnyPublisher<Bool, Never> {
        $isOnline.eraseToAnyPublisher()
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}
