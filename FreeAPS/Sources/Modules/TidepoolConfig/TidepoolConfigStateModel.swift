import Combine
import LoopKit
import LoopKitUI
import SwiftUI
import TidepoolServiceKit

extension TidepoolConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Published var serviceUIType: ServiceUI.Type?
        @Published var setupTidepool = false
        @Published var isConnected = false

        override func subscribe() {
            serviceUIType = TidepoolService.self as? ServiceUI.Type
            refreshConnectionState()
        }

        func refreshConnectionState() {
            let connected = provider.tidepoolManager.getTidepoolServiceUI() != nil
            // The Tidepool plugin invokes onboarding callbacks off the main thread;
            // @Published mutations must happen on main.
            if Thread.isMainThread {
                isConnected = connected
            } else {
                DispatchQueue.main.async { self.isConnected = connected }
            }
        }

        var pluginHost: PluginHost? {
            provider.tidepoolManager.getTidepoolPluginHost()
        }

        var serviceUI: ServiceUI? {
            provider.tidepoolManager.getTidepoolServiceUI()
        }
    }
}

extension TidepoolConfig.StateModel: ServiceOnboardingDelegate {
    func serviceOnboarding(didCreateService service: Service) {
        debug(.service, "Tidepool service \(service.pluginIdentifier) created")
        provider.tidepoolManager.addTidepoolService(service: service)
        refreshConnectionState()
    }

    func serviceOnboarding(didOnboardService service: Service) {
        precondition(service.isOnboarded)
        debug(.service, "Tidepool service \(service.pluginIdentifier) onboarded")
        refreshConnectionState()
    }
}

extension TidepoolConfig.StateModel: CompletionDelegate {
    func completionNotifyingDidComplete(_: CompletionNotifying) {
        DispatchQueue.main.async {
            self.setupTidepool = false
            self.refreshConnectionState()
            self.provider.tidepoolManager.forceTidepoolDataUpload()
        }
    }
}
