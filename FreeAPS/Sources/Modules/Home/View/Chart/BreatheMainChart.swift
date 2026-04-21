import Charts
import Foundation
import SwiftUI

extension Home {
    struct BreatheMainChart: View {
        @ObservedObject var data: ChartModel

        @State private var selectedEventID: String? = nil
        @State private var scrollPosition = Date()

        // MARK: Domain

        private var now: Date { Date() }

        /// Always load 24 h of data so scrolling has content.
        private var dataStart: Date { now.addingTimeInterval(-24 * 3600) }
        private var xEnd: Date { now.addingTimeInterval(3600) }

        /// The visible window start when not scrolling (right-aligned).
        private var visibleStart: Date { now.addingTimeInterval(-Double(data.screenHours) * 3600) }

        private var isScrollable: Bool { data.screenHours < 24 }

        /// Visible domain length in seconds for `chartXVisibleDomain`.
        private var visibleDomainLength: Int {
            (data.screenHours + 1) * 3600 // +1 h for the prediction area
        }

        // MARK: Units helpers

        private var isMmolL: Bool { data.units == .mmolL }

        private func display(_ mgdl: Int) -> Double {
            isMmolL ? Double(mgdl) * 0.0555 : Double(mgdl)
        }

        private func display(_ dec: Decimal) -> Double {
            let v = NSDecimalNumber(decimal: dec).doubleValue
            return isMmolL ? v * 0.0555 : v
        }

        private var lowThreshold: Double { display(data.lowGlucose) }
        private var highThreshold: Double { display(data.highGlucose) }

        // MARK: Hour grid dates

        /// Whole-hour dates between dataStart and xEnd, stepped by hourStride.
        private var hourGridDates: [Date] {
            let cal = Calendar.current
            guard let firstHour = cal.nextDate(
                after: dataStart.addingTimeInterval(-1),
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) else { return [] }
            var dates: [Date] = []
            var d = firstHour
            let step = Double(hourStride) * 3600
            while d <= xEnd {
                dates.append(d)
                d = d.addingTimeInterval(step)
            }
            return dates
        }

        /// Slight y-shortening for hour grid lines so they don't kiss the top edge.
        /// Chart plot height varies, but ~5 px ≈ 2.5 % of a typical 200 px chart.
        private var hourLineTop: Double {
            let range = yDomain.upperBound - yDomain.lowerBound
            return yDomain.upperBound - range * 0.05
        }

        // MARK: Y range

        private var yDomain: ClosedRange<Double> {
            if isMmolL {
                return 2.0 ... 16.0
            } else {
                return 40.0 ... 280.0
            }
        }

        // MARK: Glucose points

        private struct GluPoint: Identifiable {
            var id: Date { date }
            let date: Date
            let value: Double
            let color: Color
        }

        private var gluPoints: [GluPoint] {
            data.glucose
                .filter { $0.dateString >= dataStart }
                .compactMap { g -> GluPoint? in
                    guard let sgv = g.glucose ?? g.sgv else { return nil }
                    let v = display(sgv)
                    let c = BreathePalette.zoneColor(
                        value: v,
                        low: lowThreshold,
                        high: highThreshold,
                        isMmolL: isMmolL
                    )
                    return GluPoint(date: g.dateString, value: v, color: c)
                }
        }

        // MARK: Predictions

        private struct PredPoint: Identifiable {
            var id: Date { date }
            let date: Date
            let value: Double
        }

        private var predPoints: [PredPoint] {
            guard !data.hidePredictions,
                  let deliverAt = data.suggestion?.deliverAt ?? data.suggestion?.timestamp,
                  let iob = data.suggestion?.predictions?.iob
            else { return [] }
            return iob.enumerated().map { idx, v in
                PredPoint(
                    date: deliverAt.addingTimeInterval(TimeInterval(idx * 5 * 60)),
                    value: display(v)
                )
            }
            .filter { $0.date <= xEnd }
        }

        // MARK: Events

        private enum EventKind { case bolus, meal, fpu }

        private struct Event: Identifiable {
            /// Stable ID: date + kind ensures uniqueness even when
            /// bolus and meal share the same timestamp.
            var id: String { "\(kind)-\(date.timeIntervalSince1970)" }
            let date: Date
            let kind: EventKind
            let value: Double
            let intensity: Double
        }

        private var events: [Event] {
            var out: [Event] = []
            let maxBolus = NSDecimalNumber(decimal: data.maxBolusValue).doubleValue
            for b in data.boluses where b.timestamp >= dataStart && b.timestamp <= xEnd {
                guard let amt = b.amount else { continue }
                let v = NSDecimalNumber(decimal: amt).doubleValue
                guard v > 0 else { continue }
                let intensity = min(1.0, max(0.15, v / max(maxBolus, 1)))
                out.append(Event(date: b.timestamp, kind: .bolus, value: v, intensity: intensity))
            }
            let maxCarbs = NSDecimalNumber(decimal: data.maxCarbsValue).doubleValue
            for c in data.carbs where c.actualDate ?? c.createdAt >= dataStart
                && (c.actualDate ?? c.createdAt) <= xEnd
            {
                let date = c.actualDate ?? c.createdAt
                let v = NSDecimalNumber(decimal: c.carbs).doubleValue
                guard v > 0 else { continue }
                let isFPU = c.isFPU == true
                if isFPU {
                    guard data.fpus else { continue }
                    let intensity = min(0.6, max(0.1, v / max(maxCarbs, 1)))
                    out.append(Event(date: date, kind: .fpu, value: v, intensity: intensity))
                } else {
                    let intensity = min(1.0, max(0.25, v / max(maxCarbs, 1)))
                    out.append(Event(date: date, kind: .meal, value: v, intensity: intensity))
                }
            }
            return out
        }

        // MARK: - Header

        private static let hourOptions: [Int] = [3, 6, 12, 24]

        private var chartHeading: String {
            switch data.screenHours {
            case 3: return NSLocalizedString("3 hours", comment: "")
            case 6: return NSLocalizedString("6 hours", comment: "")
            case 12: return NSLocalizedString("12 hours", comment: "")
            case 24: return NSLocalizedString("Today", comment: "")
            default: return "\(data.screenHours) hours"
            }
        }

        private func cycleHours() {
            let opts = Self.hourOptions
            let i = opts.firstIndex(of: data.screenHours) ?? 0
            let next = opts[(i + 1) % opts.count]
            data.screenHours = next
            scrollPosition = now.addingTimeInterval(-Double(next) * 3600)
        }

        private var labelColor: Color {
            colorScheme == .dark ? .white : Color.primary
        }

        private var headerRow: some View {
            HStack {
                Text(chartHeading)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                /* .background(
                     Capsule()
                         .fill(.thinMaterial)
                         .overlay(Capsule().stroke(BreathePalette.daemmer.opacity(0.2), lineWidth: 0.5))
                         .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                 ) */
                Spacer()
                Button(action: cycleHours) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(BreathePalette.daemmer)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.thinMaterial)
                                .overlay(Capsule().stroke(BreathePalette.daemmer.opacity(0.2), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }

        // MARK: - Visible window

        private var visibleWindowStart: Date {
            isScrollable ? scrollPosition : visibleStart
        }

        private var visibleWindowEnd: Date {
            visibleWindowStart.addingTimeInterval(Double(visibleDomainLength))
        }

        // MARK: - Body

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(spacing: 2) {
                headerRow
                glucoseStave
                eventStave
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: 8, y: 3)
            .padding(.horizontal, 10)
            .onAppear {
                scrollPosition = visibleStart
            }
            .onChange(of: data.screenHours) {
                scrollPosition = now.addingTimeInterval(-Double(data.screenHours) * 3600)
            }
            .onChange(of: data.glucose.last?.dateString) { _, _ in
                guard isScrollable else { return }
                let liveStart = now.addingTimeInterval(-Double(data.screenHours) * 3600)
                let drift = abs(scrollPosition.timeIntervalSince(liveStart))
                guard drift < Double(data.screenHours) * 1800 else { return }
                withAnimation(.linear(duration: 0.25)) {
                    scrollPosition = liveStart
                }
            }
        }

        // MARK: - Top stave: glucose

        private var glucoseStave: some View {
            Chart {
                // In-range band
                RectangleMark(
                    xStart: .value("start", dataStart),
                    xEnd: .value("end", xEnd),
                    yStart: .value("lo", lowThreshold),
                    yEnd: .value("hi", highThreshold)
                )
                .foregroundStyle(BreathePalette.salbei.opacity(0.12))

                // Threshold rules
                RuleMark(y: .value("low", lowThreshold))
                    .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
                    .foregroundStyle(BreathePalette.daemmer.opacity(0.6))
                RuleMark(y: .value("high", highThreshold))
                    .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
                    .foregroundStyle(BreathePalette.kamille.opacity(0.7))

                // Hour grid lines (shortened at top by ~5 px so they don't kiss the edge)
                if data.displayXgridLines {
                    ForEach(hourGridDates, id: \.self) { d in
                        RuleMark(
                            x: .value("hour", d),
                            yStart: .value("lo", yDomain.lowerBound),
                            yEnd: .value("hi", hourLineTop)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(labelColor.opacity(0.30))
                    }
                }

                // Now-line
                RuleMark(x: .value("now", now))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(labelColor.opacity(0.25))

                // Glucose line + dots
                ForEach(gluPoints) { p in
                    LineMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(BreathePalette.salbei.opacity(0.8))
                }
                ForEach(gluPoints) { p in
                    PointMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value)
                    )
                    .symbolSize(12)
                    .foregroundStyle(p.color)
                }

                // Predictions — dashed lavender
                ForEach(predPoints) { p in
                    LineMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value),
                        series: .value("series", "predIOB")
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(BreathePalette.flieder.opacity(0.85))
                }
            }
            .chartXScale(domain: dataStart ... xEnd)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [lowThreshold, highThreshold]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatY(v))
                                .font(.system(size: 10, weight: .medium, design: .serif))
                                .foregroundStyle(colorScheme == .dark ? labelColor : labelColor.opacity(0.7))
                        }
                    }
                }
            }
            .chartXAxis {
                // Ticks + default label area —  malen der Labels selbst via chartOverlay,
                // damit sie pixelgenau über den Stunden-Linien stehen. AxisMarks bleibt nur,
                // um den Axis-Footer-Raum (18 pt) zu reservieren.
                AxisMarks(values: .stride(by: .hour, count: hourStride)) { _ in
                    AxisValueLabel { Text(" ").font(.system(size: 10)) }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let plot = proxy.plotFrame {
                        let plotRect = geo[plot]
                        ZStack(alignment: .topLeading) {
                            ForEach(hourGridDates, id: \.self) { date in
                                if let x = proxy.position(forX: date) {
                                    Text(hourFormatter.string(from: date))
                                        .font(.system(size: 10, weight: .medium, design: .serif))
                                        .foregroundStyle(colorScheme == .dark ? labelColor : labelColor.opacity(0.7))
                                        .fixedSize()
                                        .position(x: plotRect.minX + x, y: plotRect.maxY + 10)
                                }
                            }
                        }
                    }
                }
            }
            .if(isScrollable) { chart in
                chart
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: visibleDomainLength)
                    .chartScrollPosition(x: $scrollPosition)
            }
            .chartLegend(.hidden)
        }

        private var hourStride: Int {
            switch data.screenHours {
            case ..<4: return 1
            case 4 ..< 8: return 2
            case 8 ..< 16: return 3
            default: return 6
            }
        }

        private var hourFormatter: DateFormatter {
            let f = DateFormatter()
            f.dateFormat = "HH"
            return f
        }

        private func formatY(_ v: Double) -> String {
            if isMmolL {
                return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
            }
            return "\(Int(v))"
        }

        // MARK: - Event stave (separate lane below glucose chart)

        private let yAxisTrailingWidth: CGFloat = 32
        private let eventStaveHeight: CGFloat = 82
        private let bolusLaneYs: [Double] = [38, 50, 62]

        private var eventStave: some View {
            GeometryReader { geo in
                let w = geo.size.width - yAxisTrailingWidth
                let winStart = visibleWindowStart
                let winEnd = visibleWindowEnd
                let total = winEnd.timeIntervalSince(winStart)
                let mealLaneY: Double = 14

                // Build a stable lane assignment for bolus events by
                // chronological order.
                let bolusOrder: [String: Int] = {
                    let sorted = events
                        .filter { $0.kind == .bolus }
                        .sorted { $0.date < $1.date }
                    return Dictionary(
                        uniqueKeysWithValues: sorted.enumerated().map { ($1.id, $0) }
                    )
                }()

                ZStack {
                    // Notenblatt-Andeutung: 5 dezente horizontale Linien im
                    // Bereich der Bolus-Lanes, wie ein klassisches Notensystem.
                    Canvas { ctx, size in
                        let lineYs: [CGFloat] = [30, 42, 54, 66, 78]
                        let color = labelColor.opacity(colorScheme == .dark ? 0.12 : 0.08)
                        for y in lineYs {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(color), lineWidth: 0.4)
                        }
                    }
                    .frame(width: w, height: eventStaveHeight)
                    .allowsHitTesting(false)

                    // Violinschlüssel links am Notensystem
                    Text("𝄞")
                        .font(.system(size: 58, weight: .regular))
                        .foregroundStyle(labelColor.opacity(colorScheme == .dark ? 0.18 : 0.14))
                        .position(x: 10, y: 52)
                        .allowsHitTesting(false)

                    // Schlüssel belegt ~38pt links; Events, deren echte X-Position
                    // dort oder davor liegt, gelten als "hinter dem Schlüssel" und
                    // werden nicht gezeichnet — kein Stau, sauberes Rein-/Rausscrollen.
                    let clefEndX: Double = 38
                    ForEach(events) { ev in
                        let frac = ev.date.timeIntervalSince(winStart) / total
                        let naturalX = frac * w
                        if naturalX >= clefEndX, naturalX <= w - 12 {
                            let x = naturalX
                            let y: Double = {
                                switch ev.kind {
                                case .bolus:
                                    let idx = bolusOrder[ev.id] ?? 0
                                    return bolusLaneYs[idx % bolusLaneYs.count]
                                case .fpu,
                                     .meal:
                                    return mealLaneY
                                }
                            }()
                            eventIcon(for: ev)
                                .opacity(
                                    selectedEventID == nil || selectedEventID == ev.id
                                        ? 1.0 : 0.35
                                )
                                .position(x: x, y: y)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedEventID = (selectedEventID == ev.id) ? nil : ev.id
                                    }
                                }
                        }
                    }
                    if let selected = events.first(where: { $0.id == selectedEventID }) {
                        let frac = selected.date.timeIntervalSince(winStart) / total
                        tooltip(for: selected)
                            .position(x: tooltipX(frac: frac, width: w), y: -4)
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    }
                }
                .frame(width: w, height: eventStaveHeight)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEventID = nil
                    }
                }
            }
            .frame(height: eventStaveHeight)
        }

        private func tooltipX(frac: Double, width w: Double) -> Double {
            let half = 58.0
            return max(half + 4, min(w - half - 4, frac * w))
        }

        // MARK: - Event icons

        @ViewBuilder private func eventIcon(for ev: Event) -> some View {
            let baseSize: Double = 14 + ev.intensity * 10
            switch ev.kind {
            case .bolus:
                let showLabel = ev.value >= NSDecimalNumber(decimal: data.minimumSMB).doubleValue
                VStack(spacing: 1) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: baseSize * 0.7, weight: .regular))
                        .foregroundStyle(
                            colorScheme == .dark
                                ? BreathePalette.daemmer.opacity(0.9)
                                : BreathePalette.daemmer.opacity(0.7)
                        )
                    if showLabel {
                        Text(bolusLabel(ev.value))
                            .font(.system(size: 8, weight: .medium, design: .serif))
                            .foregroundStyle(
                                colorScheme == .dark
                                    ? BreathePalette.daemmer.opacity(1.0)
                                    : BreathePalette.daemmer.opacity(1.0)
                            )
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            case .meal:
                VStack(spacing: 1) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: baseSize * 0.7, weight: .regular))
                        .foregroundStyle(BreathePalette.kamille)
                    Text("\(Int(ev.value)) g")
                        .font(.system(size: 8, weight: .medium, design: .serif))
                        .foregroundStyle(BreathePalette.kamille)
                        .lineLimit(1)
                        .fixedSize()
                }
            case .fpu:
                VStack(spacing: 1) {
                    Circle()
                        .fill(BreathePalette.kamille.opacity(0.45))
                        .frame(width: 4 + ev.intensity * 4, height: 4 + ev.intensity * 4)
                    if data.fpuAmounts {
                        Text(fpuLabel(ev.value))
                            .font(.system(size: 7, weight: .regular, design: .serif))
                            .foregroundStyle(BreathePalette.kamille.opacity(0.7))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }

        private func bolusLabel(_ v: Double) -> String {
            String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
        }

        private func fpuLabel(_ v: Double) -> String {
            v >= 1 ? String(format: "%.0f", v) : String(format: "%.1f", v)
                .replacingOccurrences(of: ".", with: ",")
        }

        @ViewBuilder private func tooltip(for ev: Event) -> some View {
            let title = ev.kind == .bolus ? "Bolus" : "Meal"
            let unit = ev.kind == .bolus ? "E" : "g"
            let valueStr = ev.kind == .bolus
                ? String(format: "%.1f", ev.value).replacingOccurrences(of: ".", with: ",")
                : String(format: "%.0f", ev.value)
            let tint: Color = ev.kind == .bolus ? BreathePalette.daemmer : BreathePalette.kamille

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                Text("·").font(.system(size: 11)).foregroundStyle(.tertiary)
                Text("\(valueStr) \(unit)")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(tint)
                Text("·").font(.system(size: 11)).foregroundStyle(.tertiary)
                Text(clockFormatter.string(from: ev.date))
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(BreathePalette.strokeLight, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
        }

        private var clockFormatter: DateFormatter {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }
    }
}
