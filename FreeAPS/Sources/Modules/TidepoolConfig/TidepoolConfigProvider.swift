import Combine
import Foundation

extension TidepoolConfig {
    final class Provider: BaseProvider, TidepoolConfigProvider {
        @Injected() var tidepoolManager: TidepoolManager!
    }
}
