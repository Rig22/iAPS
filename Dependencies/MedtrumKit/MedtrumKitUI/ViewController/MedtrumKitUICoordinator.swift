import Combine
import LoopKit
import LoopKitUI
import SwiftUI
import UIKit

enum MedtrumUIScreen {
    case welcomeScreen
    case insulinTypeScreen
    case patchSettingsScreen
    case deactivatePatchScreen
    case pumpBaseSettingsScreen
    case patchPrimingScreen
    case patchActivationScreen
    case settingsScreen
}

class MedtrumKitUICoordinator: UINavigationController, PumpManagerOnboarding, CompletionNotifying,
                               UINavigationControllerDelegate
{
    private let colorPalette: LoopUIColorPalette
    private var pumpManager: MedtrumPumpManager?
    private var allowedInsulinTypes: [InsulinType]
    private var allowDebugFeatures: Bool
    private let logger = MedtrumLogger(category: "MedtrumKitUICoordinator")
    
    var screenStack = [MedtrumUIScreen]()
    var currentScreen: MedtrumUIScreen {
        return screenStack.last!
    }
    
    init(
        pumpManager: MedtrumPumpManager? = nil,
        colorPalette: LoopUIColorPalette,
        pumpManagerSettings: PumpManagerSetupSettings? = nil,
        allowDebugFeatures: Bool,
        allowedInsulinTypes: [InsulinType] = []
    )
    {
        if pumpManager == nil && pumpManagerSettings == nil {
            self.pumpManager = MedtrumPumpManager(state: MedtrumPumpState(rawValue: [:]))
        } else if pumpManager == nil, let pumpManagerSettings = pumpManagerSettings {
            self.pumpManager = MedtrumPumpManager(state: MedtrumPumpState(pumpManagerSettings.basalSchedule))
        } else {
            self.pumpManager = pumpManager
        }
        
        self.colorPalette = colorPalette
        self.allowDebugFeatures = allowDebugFeatures
        self.allowedInsulinTypes = allowedInsulinTypes
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }
    
    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if screenStack.isEmpty {
            screenStack = [getInitialScreen()]
            let viewController = viewControllerForScreen(currentScreen)
            viewController.isModalInPresentation = false
            setViewControllers([viewController], animated: false)
        }
    }
    
    func getInitialScreen() -> MedtrumUIScreen {
        guard let pumpManager = self.pumpManager else {
            return .settingsScreen
        }
        
        if !pumpManager.isOnboarded {
            return .welcomeScreen
        }
        
        if pumpManager.state.sessionToken.isEmpty || pumpManager.state.pumpSN.isEmpty || pumpManager.state.pumpState.rawValue < PatchState.primed.rawValue {
            return .pumpBaseSettingsScreen
        }
        
        if pumpManager.state.patchId.isEmpty || pumpManager.state.pumpState.rawValue < PatchState.active.rawValue {
            return .patchActivationScreen
        }
        
        return .settingsScreen
    }
    
    private func viewControllerForScreen(_ screen: MedtrumUIScreen) -> UIViewController {
        switch screen {
        case .welcomeScreen:
            return hostingController(rootView: OnboardingWelcomeView(nextStep: { self.navigateTo(.insulinTypeScreen) }))
            
        case .insulinTypeScreen:
            let nextStep: (InsulinType) -> Void = { insulinType in
                self.pumpManager?.state.insulinType = insulinType
                self.pumpManager?.notifyStateDidChange()
                
                self.navigateTo(.patchSettingsScreen)
            }
            return hostingController(rootView: InsulinTypeSelector(initialValue: allowedInsulinTypes[0], supportedInsulinTypes: allowedInsulinTypes, didConfirm: nextStep))
            
        case .patchSettingsScreen:
            let nextStep = {
                if let pumpManager = self.pumpManager {
                    pumpManager.state.isOnboarded = true
                    pumpManager.notifyStateDidChange()
                    
                    if let pumpManagerOnboardingDelegate = self.pumpManagerOnboardingDelegate {
                        pumpManagerOnboardingDelegate.pumpManagerOnboarding(didCreatePumpManager: pumpManager)
                    } else {
                        self.logger.warning("Not onboarded -> no onboardDelegate...")
                    }
                }
                
                self.navigateTo(.pumpBaseSettingsScreen)
            }
            let viewModel = PatchSettingsViewModel(pumpManager, updatePatch: false, nextStep: nextStep)
            return hostingController(rootView: PatchSettingsView(viewModel: viewModel, doDirtyCheck: false))
            
        case .deactivatePatchScreen:
            let nextStep = { self.resetNavigationTo(.pumpBaseSettingsScreen) }
            let viewModel = DeactivatePatchViewModel(pumpManager, nextStep)
            return hostingController(rootView: PatchDeactivationView(viewModel: viewModel))
            
        case .pumpBaseSettingsScreen:
            let viewModel = PumpBaseSettingsViewModel(pumpManager, {  self.navigateTo(.patchPrimingScreen) })
            return hostingController(rootView: PumpBaseSettingsView(viewModel: viewModel))
            
        case .patchPrimingScreen:
            let viewModel = PatchPrimingViewModel(pumpManager, { self.resetNavigationTo(.patchActivationScreen) }, { self.resetNavigationTo(.settingsScreen) })
            return hostingController(rootView: PatchPrimingView(viewModel: viewModel))
            
        case .patchActivationScreen:
            let viewModel = PatchActivationViewModel(pumpManager, { self.resetNavigationTo(.settingsScreen) })
            return hostingController(rootView: PatchActivationView(viewModel: viewModel))
            
        case .settingsScreen:
            let toDeactivation = {
                self.navigateTo(.deactivatePatchScreen)
            }
            let toActivation: (Bool) -> Void = { alreadyPrimed in
                self.navigateTo(alreadyPrimed ? .patchActivationScreen : .patchPrimingScreen)
            }
            let pumpRemoval = {
                guard let completionDelegate = self.completionDelegate else {
                    return
                }
                completionDelegate.completionNotifyingDidComplete(self)
            }
            
            let viewModel = MedtrumKitSettingsViewModel(self.pumpManager, toDeactivation, toActivation, pumpRemoval)
            return hostingController(rootView: MedtrumKitSettings(viewModel: viewModel, supportedInsulinTypes: allowedInsulinTypes))
        }
    }
    
    private func hostingController<Content: View>(rootView: Content) -> DismissibleHostingController {
        let rootView = rootView
            .environment(\.appName, Bundle.main.bundleDisplayName)
        return DismissibleHostingController(rootView: rootView, colorPalette: colorPalette)
    }
    
    var pumpManagerOnboardingDelegate: (any LoopKitUI.PumpManagerOnboardingDelegate)?
    
    var completionDelegate: (any LoopKitUI.CompletionDelegate)?
}

extension MedtrumKitUICoordinator {
    func navigateTo(_ screen: MedtrumUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        viewController.isModalInPresentation = false
        self.pushViewController(viewController, animated: true)
        viewController.view.layoutSubviews()
    }
    
    func resetNavigationTo(_ screen: MedtrumUIScreen) {
        screenStack = [screen]
        let viewController = viewControllerForScreen(screen)
        viewController.isModalInPresentation = false
        self.setViewControllers([viewController], animated: false)
        viewController.view.layoutSubviews()
    }
}
