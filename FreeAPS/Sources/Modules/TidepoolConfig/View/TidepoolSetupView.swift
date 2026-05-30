import LoopKit
import LoopKitUI
import SwiftUI
import UIKit

/// Bridges the Tidepool plugin's UIKit onboarding/login flow into SwiftUI.
struct TidepoolSetupView: UIViewControllerRepresentable {
    let serviceUIType: ServiceUI.Type
    let pluginHost: PluginHost
    let serviceOnboardingDelegate: ServiceOnboardingDelegate
    let completionDelegate: CompletionDelegate

    func makeUIViewController(context _: UIViewControllerRepresentableContext<TidepoolSetupView>) -> UIViewController {
        switch serviceUIType.setupViewController(colorPalette: .default, pluginHost: pluginHost) {
        case let .createdAndOnboarded(serviceUI):
            serviceOnboardingDelegate.serviceOnboarding(didCreateService: serviceUI)
            serviceOnboardingDelegate.serviceOnboarding(didOnboardService: serviceUI)
            return UIViewController()
        case var .userInteractionRequired(setupViewControllerUI):
            setupViewControllerUI.serviceOnboardingDelegate = serviceOnboardingDelegate
            setupViewControllerUI.completionDelegate = completionDelegate
            return setupViewControllerUI
        }
    }

    func updateUIViewController(_: UIViewController, context _: UIViewControllerRepresentableContext<TidepoolSetupView>) {}
}

/// Bridges the Tidepool plugin's UIKit settings screen (already-connected state) into SwiftUI.
struct TidepoolSettingsView: UIViewControllerRepresentable {
    let serviceUI: ServiceUI
    let serviceOnboardingDelegate: ServiceOnboardingDelegate
    let completionDelegate: CompletionDelegate

    func makeUIViewController(context _: UIViewControllerRepresentableContext<TidepoolSettingsView>) -> UIViewController {
        var vc = serviceUI.settingsViewController(colorPalette: .default)
        vc.serviceOnboardingDelegate = serviceOnboardingDelegate
        vc.completionDelegate = completionDelegate
        return vc
    }

    func updateUIViewController(_: UIViewController, context _: UIViewControllerRepresentableContext<TidepoolSettingsView>) {}
}
