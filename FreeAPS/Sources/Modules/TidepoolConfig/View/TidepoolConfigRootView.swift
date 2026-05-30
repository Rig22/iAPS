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
                Section(header: Text("Tidepool Integration")) {
                    if state.serviceUIType != nil {
                        Button {
                            state.setupTidepool = true
                        } label: {
                            if state.isConnected {
                                HStack {
                                    Text("Connected to Tidepool")
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("Connect to Tidepool")
                            }
                        }
                    } else {
                        Text("Tidepool service unavailable")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text(
                        "You can connect iAPS to Tidepool to upload and manage your diabetes data. " +
                            "Log in with your Tidepool credentials, or sign up on the login page.\n\n" +
                            "When connected, iAPS uploads glucose, carb entries, insulin (bolus and basal), " +
                            "and therapy settings (basal schedules, carb ratios, insulin sensitivities, glucose targets)."
                    )
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
