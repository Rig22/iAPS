import LoopKitUI
import SwiftUI
import Swinject

extension TidepoolConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            Form {
                Section(header: Text(TidepoolL10n.t("section.header"))) {
                    if state.serviceUIType != nil {
                        Button {
                            state.setupTidepool = true
                        } label: {
                            if state.isConnected {
                                HStack {
                                    Text(TidepoolL10n.t("connected"))
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text(TidepoolL10n.t("connect"))
                            }
                        }
                    } else {
                        Text(TidepoolL10n.t("unavailable"))
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text(TidepoolL10n.t("footer"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $state.setupTidepool, onDismiss: { state.refreshConnectionState() }) {
                if let serviceUIType = state.serviceUIType, let pluginHost = state.pluginHost {
                    if let serviceUI = state.serviceUI {
                        TidepoolSettingsView(
                            serviceUI: serviceUI,
                            serviceOnboardingDelegate: state,
                            completionDelegate: state
                        )
                    } else {
                        TidepoolSetupView(
                            serviceUIType: serviceUIType,
                            pluginHost: pluginHost,
                            serviceOnboardingDelegate: state,
                            completionDelegate: state
                        )
                    }
                }
            }
            .onAppear { state.refreshConnectionState() }
            .navigationTitle("Tidepool")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
