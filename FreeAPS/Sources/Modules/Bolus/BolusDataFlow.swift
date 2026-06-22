enum Bolus {
    enum Config {}

    /// Empfehlung aus dem AI-Hub-Mahlzeiten-Simulator, einmalig übergeben kurz
    /// bevor der Bolus-Screen geöffnet wird. Der Screen zeigt sie als Banner
    /// und füllt das Bolus-Feld mit dem „jetzt"-Anteil vor. Wird beim ersten
    /// Erscheinen konsumiert und genullt.
    struct SimRecommendation: Equatable {
        let total: Double // empfohlener Gesamt-Bolus (U)
        let now: Double // jetzt zu gebender Anteil (U)
        let later: Double // späterer Anteil (U), 0 = kein Split
        let afterMinutes: Int

        var isSplit: Bool { later > 0 && afterMinutes > 0 }
    }

    static var pendingSimRecommendation: SimRecommendation?
}

protocol BolusProvider: Provider {
    var suggestion: Suggestion? { get }

    func pumpSettings() -> PumpSettings
    func fetchGlucose() -> [Readings]
    func pumpHistory() -> [PumpHistoryEvent]
}
