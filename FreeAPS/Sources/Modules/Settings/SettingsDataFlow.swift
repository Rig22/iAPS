enum Settings {
    enum Config {}
}

protocol SettingsProvider: Provider {
    func runLoop()
}
