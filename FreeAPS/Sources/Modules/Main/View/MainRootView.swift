import CoreData
import SwiftUI
import Swinject

extension Main {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel
        @Environment(\.colorScheme) var lightMode

        // First-run gate: when the Onboarding entity reports firstRun (or no
        // entity exists yet on a fresh install), render the backup-restore
        // prompt INSTEAD of the home view. This avoids instantiating the home
        // skin's state model, which would otherwise initialize and write
        // default settings to disk before the user has a chance to import.
        @FetchRequest(
            entity: Onboarding.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) private var onboarded: FetchedResults<Onboarding>

        var colorScheme: ColorScheme {
            state.lightMode != LightMode.auto ? (state.lightMode == .light ? .light : .dark) : lightMode
        }

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            Group {
                if onboarded.first?.firstRun ?? true {
                    FirstRunRestorePromptView(resolver: resolver) {
                        CoreDataStorage().saveOnbarding()
                    }
                } else {
                    router.view(for: .home)
                        .sheet(isPresented: $state.isModalPresented) {
                            NavigationView {
                                self.state.modal!.view
                                    .environmentObject(state)
                            }
                            .navigationViewStyle(StackNavigationViewStyle())
                            .interactiveDismissDisabled(state.shouldPreventModalDismiss)
                            .environment(\.colorScheme, colorScheme)
                        }
                        .sheet(isPresented: $state.isSecondaryModalPresented) {
                            state.secondaryModalView ?? EmptyView().asAny()
                        }
                }
            }
            .environment(\.colorScheme, colorScheme)
        }
    }
}
