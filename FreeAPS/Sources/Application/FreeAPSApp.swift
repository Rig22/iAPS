import ActivityKit
import CoreData
import Foundation
import SwiftUI
import Swinject

@main struct FreeAPSApp: App {
    @Environment(\.scenePhase) var scenePhase

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject var dataController = CoreDataStack.shared

    // Dependencies Assembler
    // contain all dependencies Assemblies
    // TODO: Remove static key after update "Use Dependencies" logic
    private static let assembler = Assembler([
        StorageAssembly(),
        ServiceAssembly(),
        APSAssembly(),
        NetworkAssembly(),
        UIAssembly(),
        SecurityAssembly()
    ], parent: nil, defaultObjectScope: .container)

    // Temp static var
    // Use to backward compatibility with old Dependencies logic on Logger
    // TODO: Remove var after update "Use Dependencies" logic in Logger
    static let resolver: Resolver = FreeAPSApp.assembler.resolver

    // TODO: do we want this? will this work with the Router?
    // can be shared with the rest of the views with @EnvironmentObject
    @StateObject private var appServices = AppServices(assembler: assembler)

    init() {
        // Two-phase backup restore: if a pending bundle was staged on the
        // previous run, write all settings files to disk BEFORE any Swinject
        // assembly or service initialization. This eliminates the race where
        // a runtime restore could be overwritten by in-memory caches of
        // SettingsManager / NightscoutManager / DeviceDataManager etc.
        // Must run before anything that touches `FreeAPSApp.resolver` or
        // `appServices`, both of which trigger the lazy assembler init.
        EarlyBackupRestore.applyIfPending()

        debug(
            .default,
            "iAPS Started: v\(Bundle.main.releaseVersionNumber ?? "")(\(Bundle.main.buildVersionNumber ?? "")) [buildDate: \(Bundle.main.buildDate)] [buildExpires: \(Bundle.main.profileExpiration ?? "")]"
        )
        isNewVersion()
        AppearanceManager.setupGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Main.RootView(resolver: FreeAPSApp.resolver)
                .environment(\.managedObjectContext, dataController.persistentContainer.viewContext)
                .environmentObject(Icons())
                .onOpenURL(perform: handleURL)
                .environmentObject(appServices)
        }
        .onChange(of: scenePhase) {
            debug(.default, "APPLICATION PHASE: \(scenePhase)")
            if scenePhase == .active {
                appServices.deviceManager.didBecomeActive()
                appServices.autoBackupService.checkDailyTrigger()
            }
        }
    }

    private func handleURL(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch components?.host {
        case "device-select-resp":
            FreeAPSApp.resolver.resolve(NotificationCenter.self)!.post(name: .openFromGarminConnect, object: url)
        default: break
        }
    }

    private func isNewVersion() {
        let userDefaults = UserDefaults.standard
        var version = userDefaults.string(forKey: IAPSconfig.version) ?? ""
        userDefaults.set(false, forKey: IAPSconfig.inBolusView)

        guard version.count > 1, version == (Bundle.main.releaseVersionNumber ?? "") else {
            version = Bundle.main.releaseVersionNumber ?? ""
            userDefaults.set(version, forKey: IAPSconfig.version)
            userDefaults.set(true, forKey: IAPSconfig.newVersion)
            debug(.default, "Running new version: \(version)")
            return
        }
    }
}
