import Combine
import Foundation

enum TidepoolConfig {}

protocol TidepoolConfigProvider: Provider {
    var tidepoolManager: TidepoolManager! { get }
}
