/// Rig22
import SwiftUI

extension Home {
    struct TopStatusPill: View {
        @ObservedObject var state: Home.StateModel
        @Environment(\.colorScheme) var colorScheme

        @State private var isDetailSheetPresented = false

        // Timer für das Rollieren (alle 60 Sek)
        let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

        fileprivate struct DisplayStatus: Identifiable {
            let id = UUID()
            let message: String
            let icon: String
            let color: Color
            let messageColor: Color
            let priority: Int
        }

        var body: some View {
            let allStatuses = getAllActiveStatuses()
            let currentStatus = getCurrentRotationStatus(from: allStatuses)
            let isBolusing = (state.bolusProgress ?? 0) > 0

            HStack(spacing: 0) {
                Image(systemName: currentStatus.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(currentStatus.color)
                    .frame(width: 24, height: 24)
                    .shadow(color: currentStatus.color.opacity(0.3), radius: 3, x: 0, y: 0)
                    .padding(.leading, 12)

                Text(currentStatus.message)
                    .font(.system(size: 17, weight: .light).monospacedDigit())
                    .foregroundColor(currentStatus.messageColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.trailing, 12)
            }
            .frame(minWidth: UIScreen.main.bounds.width * 0.6)
            .frame(maxWidth: UIScreen.main.bounds.width - 30)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 44)
            .padding(.vertical, 2)
            .background(pillBackground(isBolusing: isBolusing))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                state.isStatusPopupPresented = true
            }
            .onLongPressGesture(minimumDuration: 0.2) {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                isDetailSheetPresented = true
            }
            .onReceive(timer) { _ in
                // Der Timer triggert das UI-Update für das Rollieren
            }
            .sheet(isPresented: $isDetailSheetPresented) {
                StatusDetailView(statuses: allStatuses)
            }
        }

        // MARK: - Vollständige Logik-Sammlung

        private func getAllActiveStatuses() -> [DisplayStatus] {
            var pool: [DisplayStatus] = []

            // 1. Bolus
            if let bolusProgress = state.bolusProgress, bolusProgress > 0 {
                let amount = (state.bolusAmount ?? 0) as NSDecimalNumber
                let progress = (bolusProgress as NSDecimalNumber).doubleValue
                let total = amount.doubleValue
                let delivered = total * progress

                pool.append(DisplayStatus(
                    message: "Bolus: \(String(format: "%.2f", delivered)) / \(String(format: "%.2f", total)) U",
                    icon: "syringe.fill",
                    color: .blue,
                    messageColor: .primary,
                    priority: 1000
                ))
            }

            // 2. Looping Status
            if state.isLooping {
                pool.append(DisplayStatus(
                    message: "Looping aktiv",
                    icon: "arrow.triangle.2.circlepath",
                    color: .green,
                    messageColor: .primary,
                    priority: 950
                ))
            }

            // 2. Sensor Info (Batterie/Laufzeit)
            if let sensor = state.calculateSensorInfo() {
                pool.append(DisplayStatus(
                    message: sensor.text,
                    icon: "sensor.tag.radiowaves.forward",
                    color: sensor.color,
                    messageColor: .primary,
                    priority: sensor.priority
                ))
            }

            // 3. Delta & Trend auf CGM Basis
            /*      if let delta = state.glucoseDelta {
                 let trendIcon = delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                 pool.append(DisplayStatus(
                     message: "Delta: \(delta > 0 ? "+" : "")\(delta) mg/dL",
                     icon: trendIcon,
                     color: .primary,
                     messageColor: .primary,
                     priority: 500
                 ))
             }*/

            // 3. PUMPENSTATUS (Patch)
            if let expiresAt = state.pumpExpiresAtDate {
                let remaining = expiresAt.timeIntervalSince(Date())
                let hours = Int(remaining / 3600)
                let minutes = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)

                // Nur anzeigen, wenn weniger als 24 Stunden übrig ODER bereits abgelaufen
                if remaining <= 24 * 3600 {
                    let isExpired = remaining <= 0

                    // Icon
                    let icon: String
                    if isExpired {
                        icon = "exclamationmark.shield.fill"
                    } else {
                        icon = hours <= 5 ? "exclamationmark.triangle.fill" : "timer"
                    }

                    // Farbbe
                    let color: Color
                    if isExpired {
                        color = .red
                    } else {
                        color = hours <= 8 ? .orange : .blue
                    }

                    // Text
                    let message: String
                    if isExpired {
                        message = NSLocalizedString("Replace", comment: "")
                    } else {
                        let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)min"
                        message = "Patch: \(timeString)"
                    }

                    pool.append(DisplayStatus(
                        message: message,
                        icon: icon,
                        color: color,
                        messageColor: isExpired ? .red : .secondary,
                        priority: isExpired ? 900 : 700
                    ))
                }
            }

            // 5. RESERVOIR
            if let reservoir = state.reservoir, reservoir < 10 {
                let reservoirDouble = (reservoir as NSDecimalNumber).doubleValue
                pool.append(DisplayStatus(
                    message: "Reservoir: \(Int(reservoirDouble))U",
                    icon: "fuelpump.fill",
                    color: reservoirDouble < 5 ? .red : .orange,
                    messageColor: .primary, priority: 500
                ))
            }

            // 6. SENSOR-STATUS
            /*     if state.displayExpiration || state.displaySAGE,
                let sensor = state.calculateSensorInfo()
             {
                 if sensor.timeToShow < 86400 {
                     pool.append(DisplayStatus(
                         message: sensor.text,
                         icon: "sensor.tag.radiowaves.forward",
                         color: sensor.color,
                         messageColor: .primary,
                         priority: sensor.priority
                     ))
                 }
             }*/

            // 7. LOOP-STATUS: Loop hängt
            let timeSinceLastLoop = -state.lastLoopDate.timeIntervalSinceNow
            let minutesSinceLoop = Int(timeSinceLastLoop / 60)

            if minutesSinceLoop > 5 {
                let isCritical = minutesSinceLoop > 10
                let localizedMessage = String(
                    format: NSLocalizedString("Last loop was more than %d min ago", comment: ""),
                    minutesSinceLoop
                )

                pool.append(DisplayStatus(
                    message: localizedMessage,
                    icon: "arrow.triangle.2.circlepath",
                    color: isCritical ? .red : .orange,
                    messageColor: .primary,
                    priority: isCritical ? 430 : 400,
                ))
            }

            // 8. PUMPENSTATUS: Pump suspended
            if state.pumpSuspended {
                pool.append(DisplayStatus(
                    message: "Pump suspended",
                    icon: "pause.circle.fill",
                    color: .gray,
                    messageColor: .gray,
                    priority: 360,
                ))
            }

            // 9. DELTA
            if let delta = state.glucoseDelta {
                let absDelta = abs(delta)
                let isRising = delta > 0
                let trendDescription: String
                let icon: String

                // Deine Vorgabe: +/- 3 ist "Stabil"
                if absDelta <= 3 {
                    trendDescription = NSLocalizedString("Stable", comment: "")
                    icon = "arrow.right"
                } else if absDelta < 10 {
                    // Leicht steigend / sinkend
                    trendDescription = isRising ? NSLocalizedString("Slightly rising", comment: "") :
                        NSLocalizedString("Slightly falling", comment: "")
                    icon = isRising ? "arrow.up.right" : "arrow.down.right"
                } else if absDelta < 15 {
                    // Steigend / Sinkend
                    trendDescription = isRising ? NSLocalizedString("Rising", comment: "") :
                        NSLocalizedString("Falling", comment: "")
                    icon = isRising ? "arrow.up" : "arrow.down"
                } else {
                    // Stark steigend / sinkend (ab 15 mg/dL)
                    trendDescription = isRising ? NSLocalizedString("Strongly rising", comment: "") :
                        NSLocalizedString("Strongly falling", comment: "")
                    icon = isRising ? "chevron.up.2" : "chevron.down.2"
                }

                let deltaString = isRising ? "+\(delta)" : "\(delta)"
                let fullMessage = "\(trendDescription) (\(deltaString))"

                // Sofort-Anzeige bei massiven Änderungen (Override)
                /* if absDelta >= 15 {
                     return DisplayStatus(
                         message: fullMessage,
                         icon: icon,
                         color: .red,
                         messageColor: .primary,
                         priority: 350
                     )
                 }*/

                // Zum Pool hinzufügen für das Rollieren
                pool.append(DisplayStatus(
                    message: fullMessage,
                    icon: icon,
                    color: absDelta <= 5 ? .green : .orange,
                    messageColor: .primary,
                    priority: 350
                ))
            }

            // 10. TEMP BASAL
            if let tempRate = state.tempRate {
                let rateDouble = (tempRate as NSDecimalNumber).doubleValue
                let rateString = String(format: "%.2f", rateDouble)

                let displayColor: Color = (rateDouble == 0) ? .orange : .blue

                pool.append(DisplayStatus(
                    message: "Temp: \(rateString)U/h",
                    icon: rateDouble == 0 ? "pause.circle.fill" : "chart.bar.xaxis.ascending.badge.clock",
                    color: displayColor,
                    messageColor: .primary,
                    priority: 300
                ))
            }

            // 11. SYSTEM STATUS
            pool.append(DisplayStatus(
                message: state.statusTitle,
                icon: "checkmark.shield.fill",
                color: loopColor,
                messageColor: .primary,
                priority: 50,
            ))

            return pool.sorted { $0.priority > $1.priority }
        }

        private func getCurrentRotationStatus(from sortedPool: [DisplayStatus]) -> DisplayStatus {
            // Wenn gebolust wird, zeige NUR Bolus
            if let bolus = sortedPool.first(where: { $0.priority == 1000 }) { return bolus }

            // Ansonsten rolliere alle 60 Sekunden
            let index = (Int(Date().timeIntervalSince1970) / 60) % sortedPool.count
            return sortedPool[index]
        }

        @ViewBuilder private func pillBackground(isBolusing: Bool) -> some View {
            ZStack(alignment: .leading) {
                if colorScheme != .dark {
                    LinearGradient(gradient: Gradient(colors: [
                        Color(red: 0.7, green: 0.9, blue: 0.5).opacity(0.1),
                        Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.1)
                    ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color.white.opacity(0.05)
                }

                if isBolusing, let progress = state.bolusProgress {
                    GeometryReader { geo in
                        Color.blue.opacity(0.2)
                            .frame(width: geo.size.width * CGFloat(truncating: progress as NSNumber))
                    }
                }
            }
        }

        private var loopColor: Color {
            let delta = Date().timeIntervalSince(state.lastLoopDate)
            return delta <= 300 ? .green : (delta <= 600 ? .yellow : .red)
        }
    }
}

// MARK: - Detail Sheet View

struct StatusDetailView: View {
    fileprivate let statuses: [Home.TopStatusPill.DisplayStatus]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(statuses) { status in
                HStack(spacing: 15) {
                    Image(systemName: status.icon)
                        .renderingMode(.template)
                        .font(.title3)
                        .foregroundColor(status.color)
                        .frame(width: 30)

                    Text(status.message)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Status Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 1. Linker Titel
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Status Overview")
                        .font(.headline)
                        .fixedSize(horizontal: true, vertical: false) // Verhindert das Abschneiden
                }

                // 2. Mitte leeren (hilft gegen das Abschneiden)
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1)
                }

                // 3. Rechter Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
