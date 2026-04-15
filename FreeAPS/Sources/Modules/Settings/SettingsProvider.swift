extension Settings {
    final class Provider: BaseProvider, SettingsProvider {
        @Injected() var appCoordinator: AppCoordinator!

        func runLoop() {
            appCoordinator.sendHeartbeat()
        }
    }
}
