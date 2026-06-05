import Algorithms
import Charts
import SwiftUI

/// Aurora area chart — smooth glucose history, threshold hairlines, basal
/// rate bars (gated), now-line. Hours-Switch (3/6/12/24) cycles the visible
/// window. All accents are tied to the current glucose status color, so the
/// chart breathes with the ring.
struct AuroraMainChart: View {
    @ObservedObject var data: ChartModel
    var displayBasal: Bool = false
    var displayCarbs: Bool = false
    var displayBoluses: Bool = false
    let glucoseNow: Double // mg/dL — drives status color
    var onOpenDataTable: (() -> Void)? = nil

    @State private var selectedChartDate: Date? = nil
    @State private var scrollPosition = Date().addingTimeInterval(-6 * 3600)

    @Environment(\.colorScheme) private var scheme

    private var status: AuroraGlucoseStatus { AuroraGlucoseStatus(mgdl: glucoseNow) }

    // MARK: - Hour grid (vertical lines when UIUX toggle is on)

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

    // MARK: - Domain

    private var now: Date { Date() }
    private var dataStart: Date { now.addingTimeInterval(-24 * 3600) }
    private var xEnd: Date { now.addingTimeInterval(2 * 3600) }
    private var visibleStart: Date { now.addingTimeInterval(-Double(data.screenHours) * 3600) }

    /// Visible window length (including a 2 h "future" lane for the forecast
    /// line). At 24 h the window matches the whole data range so scrolling has
    /// nothing to do.
    private var visibleDomainLength: Int { (data.screenHours + 2) * 3600 }
    private var isScrollable: Bool { data.screenHours < 24 }

    private var isMmolL: Bool { data.units == .mmolL }
    private var yLow: Double { isMmolL ? 2.0 : 45 }
    private var yHigh: Double { isMmolL ? 16.0 : 235 }

    private func display(_ mgdl: Int) -> Double {
        isMmolL ? Double(mgdl) * 0.0555 : Double(mgdl)
    }

    private func display(_ d: Decimal) -> Double {
        let v = NSDecimalNumber(decimal: d).doubleValue
        return isMmolL ? v * 0.0555 : v
    }

    private var lowThreshold: Double { display(data.lowGlucose) }
    private var highThreshold: Double { display(data.highGlucose) }

    /// Hour-label cadence — keeps the axis readable as the window grows.
    private var hourStride: Int {
        switch data.screenHours {
        case ..<4: return 1
        case 4 ..< 8: return 2
        case 8 ..< 16: return 3
        default: return 6
        }
    }

    // MARK: - Glucose points

    private struct GluPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
    }

    private var gluPoints: [GluPoint] {
        // Always load the full 24 h window (matches `dataStart`) so the
        // chart has content to show when the user scrolls back at 3/6/12 h.
        data.glucose
            .filter { $0.dateString >= dataStart }
            .compactMap { g -> GluPoint? in
                guard let sgv = g.glucose ?? g.sgv, sgv > 0 else { return nil }
                return GluPoint(date: g.dateString, value: display(sgv))
            }
            // Force ascending order — the storage hands us readings
            // newest-first, which would scramble the segment walker that
            // tracks `currentInRange` left-to-right along the timeline.
            .sorted { $0.date < $1.date }
    }

    // MARK: - Prediction line (reduced, single combined forecast)

    private struct PredPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
    }

    /// A single reduced forecast line drawn into the 2 h future lane, right of
    /// the now-line. For each 5-minute step we take the **minimum** predicted
    /// glucose across the available COB/IOB/ZT/UAM arrays — the same combined
    /// representation the orbital chart used — so the line stays calm instead
    /// of fanning out into four clouds. Anchored at `deliverAt` (≈ now) so it
    /// visually continues the live glucose curve. Clipped to `xEnd` so only the
    /// near-future portion shows. Respects the `hidePredictions` toggle.
    private var predictionPoints: [PredPoint] {
        guard !data.hidePredictions,
              let preds = data.suggestion?.predictions else { return [] }
        let start = data.suggestion?.deliverAt ?? now

        let arrays = [preds.cob, preds.iob, preds.zt, preds.uam].compactMap { $0 }
        let maxCount = arrays.map(\.count).max() ?? 0
        guard maxCount > 1 else { return [] }

        var points: [PredPoint] = []
        for index in 0 ..< maxCount {
            let candidates = arrays.compactMap { index < $0.count ? $0[index] : nil }
            guard let value = candidates.min() else { continue }
            let date = start.addingTimeInterval(TimeInterval(index) * 300)
            guard date <= xEnd else { break }
            points.append(PredPoint(date: date, value: display(value)))
        }
        return points
    }

    /// Forecast line rides the live status color but stays faint so it reads as
    /// a projection, not a measurement.
    private var predictionColor: Color { status.main.opacity(0.40) }

    // MARK: - Glucose line segments (split at threshold crossings)

    private struct LineSegment: Identifiable {
        let id: Int
        let points: [GluPoint]
        let inRange: Bool
    }

    /// Split the glucose curve into consecutive in-range and out-of-range
    /// segments. At every threshold crossing we insert an interpolated point
    /// **exactly on** the threshold so the line color switches cleanly
    /// instead of mid-segment.
    private var lineSegments: [LineSegment] {
        let pts = gluPoints
        guard !pts.isEmpty else { return [] }

        let low = lowThreshold
        let high = highThreshold

        func isInRange(_ v: Double) -> Bool { v >= low && v <= high }

        // Linear interpolation between two readings at a given y-threshold.
        func crossing(from a: GluPoint, to b: GluPoint, at y: Double) -> GluPoint {
            let span = b.value - a.value
            let t = span == 0 ? 0 : (y - a.value) / span
            let clampedT = max(0, min(1, t))
            let dt = b.date.timeIntervalSince(a.date)
            let date = a.date.addingTimeInterval(dt * clampedT)
            return GluPoint(date: date, value: y)
        }

        /// All thresholds the line crosses between a and b, in traversal order.
        /// Uses a "≥ threshold" membership check (threshold counts as
        /// in-range) so a real CGM reading that lands EXACTLY on 70 or 180
        /// still triggers the boundary toggle. The old sign-based check
        /// silently skipped such crossings — the visible symptom was an
        /// in-range bow rendered grey after a low/high reading happened to
        /// sit on the threshold.
        func crossingsBetween(_ a: GluPoint, _ b: GluPoint) -> [GluPoint] {
            var thresholds: [Double] = []
            for t in [low, high] {
                let aAbove = a.value >= t
                let bAbove = b.value >= t
                if aAbove != bAbove {
                    thresholds.append(t)
                }
            }
            return thresholds
                .sorted { abs($0 - a.value) < abs($1 - a.value) }
                .map { crossing(from: a, to: b, at: $0) }
        }

        var segments: [LineSegment] = []
        var current: [GluPoint] = [pts[0]]
        var currentInRange = isInRange(pts[0].value)
        var segId = 0

        for i in 1 ..< pts.count {
            let prev = pts[i - 1]
            let next = pts[i]
            let crosses = crossingsBetween(prev, next)

            for cross in crosses {
                current.append(cross)
                segments.append(LineSegment(id: segId, points: current, inRange: currentInRange))
                segId += 1
                current = [cross]
                currentInRange.toggle()
            }

            current.append(next)
        }

        if current.count >= 2 || segments.isEmpty {
            segments.append(LineSegment(id: segId, points: current, inRange: currentInRange))
        }
        return segments
    }

    // MARK: - Temp target / Override spans

    private struct TargetSpan: Identifiable {
        let id: String
        let start: Date
        let end: Date
        let yLow: Double
        let yHigh: Double
        let color: Color
    }

    /// Half-thickness of an override stripe in displayed units (so a single
    /// target value still renders as a visible bar).
    private var overrideBarHalfHeight: Double {
        isMmolL ? 0.15 : 3.0
    }

    private var tempTargetSpans: [TargetSpan] {
        let sorted = data.tempTargets.sorted { $0.createdAt < $1.createdAt }
        var spans: [TargetSpan] = []
        for t in sorted {
            let durationMin = NSDecimalNumber(decimal: t.duration).doubleValue
            let start = t.createdAt
            let end = start.addingTimeInterval(durationMin * 60)

            // Truncate previous span if this entry overlaps it (cancel marker etc.).
            if let prev = spans.last, prev.end > start {
                spans.removeLast()
                spans.append(TargetSpan(
                    id: prev.id, start: prev.start, end: start,
                    yLow: prev.yLow, yHigh: prev.yHigh, color: prev.color
                ))
            }

            let topDec = t.targetTop ?? 0
            let bottomDec = t.targetBottom ?? topDec
            let topVal = NSDecimalNumber(decimal: topDec).doubleValue
            let bottomVal = NSDecimalNumber(decimal: bottomDec).doubleValue
            guard durationMin > 0, topVal > 0 else { continue }
            guard end >= dataStart, start <= xEnd else { continue }

            let yTop = display(topDec)
            let yBottom = bottomVal > 0 ? display(bottomDec) : yTop
            let yLow = min(yTop, yBottom)
            let yHigh = max(yTop, yBottom)
            let pad = yHigh - yLow < overrideBarHalfHeight * 2 ? overrideBarHalfHeight : 0

            spans.append(TargetSpan(
                id: "tt-\(start.timeIntervalSince1970)",
                start: max(start, dataStart),
                end: min(end, xEnd),
                yLow: yLow - pad,
                yHigh: yHigh + pad,
                color: AuroraPalette.Status.inMain
            ))
        }
        return spans
    }

    private var overrideSpans: [TargetSpan] {
        var spans: [TargetSpan] = []

        for h in data.overrideHistory {
            guard let date = h.date else { continue }
            let durationMin = h.duration
            let target = h.target
            guard durationMin > 0, target > 0 else { continue }
            let end = date.addingTimeInterval(durationMin * 60)
            guard end >= dataStart, date <= xEnd else { continue }

            let y = display(Int(target))
            spans.append(TargetSpan(
                id: "oh-\(date.timeIntervalSince1970)",
                start: max(date, dataStart),
                end: min(end, xEnd),
                yLow: y - overrideBarHalfHeight,
                yHigh: y + overrideBarHalfHeight,
                color: AuroraPalette.pump
            ))
        }

        if let last = data.latestOverride, last.enabled, let date = last.date {
            let targetDouble = (last.target ?? 0).doubleValue
            if targetDouble >= 6 {
                let durationMin = (last.duration ?? 0).doubleValue
                let end: Date = durationMin > 0
                    ? date.addingTimeInterval(durationMin * 60)
                    : xEnd
                if end >= dataStart, date <= xEnd {
                    let y = display(Int(targetDouble))
                    spans.append(TargetSpan(
                        id: "ov-\(date.timeIntervalSince1970)",
                        start: max(date, dataStart),
                        end: min(end, xEnd),
                        yLow: y - overrideBarHalfHeight,
                        yHigh: y + overrideBarHalfHeight,
                        color: AuroraPalette.pump
                    ))
                }
            }
        }
        return spans
    }

    // MARK: - Touch selection

    /// Snap the raw chart x-coordinate (from `chartXSelection`) to the nearest
    /// real reading so the popover never floats over empty space.
    private var selectedGluPoint: GluPoint? {
        guard let target = selectedChartDate else { return nil }
        return gluPoints.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        })
    }

    /// Window in which a bolus / carb is considered "near" the finger.
    private static let nearWindow: TimeInterval = 4 * 60

    struct EventHit {
        let date: Date
        let amount: Double
    }

    private var selectedBolus: EventHit? {
        guard let target = selectedChartDate else { return nil }
        let candidates = data.boluses.compactMap { ev -> EventHit? in
            guard ev.type == .bolus,
                  let amt = ev.amount, amt > 0 else { return nil }
            return EventHit(date: ev.timestamp, amount: NSDecimalNumber(decimal: amt).doubleValue)
        }
        return candidates
            .filter { abs($0.date.timeIntervalSince(target)) <= Self.nearWindow }
            .min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
    }

    private var selectedCarb: EventHit? {
        guard let target = selectedChartDate else { return nil }
        let candidates = data.carbs.compactMap { c -> EventHit? in
            guard (c.isFPU ?? false) == false, c.carbs > 0 else { return nil }
            let when = c.actualDate ?? c.createdAt
            return EventHit(date: when, amount: NSDecimalNumber(decimal: c.carbs).doubleValue)
        }
        return candidates
            .filter { abs($0.date.timeIntervalSince(target)) <= Self.nearWindow }
            .min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
    }

    // MARK: - Permanent bolus / carb hits (drawn when toggles are on)

    /// All bolus events in the loaded 24 h window. Anchored to the glucose
    /// curve so the dot sits visually on the reading at delivery time.
    private var bolusHits: [EventHit] {
        data.boluses.compactMap { ev -> EventHit? in
            guard ev.type == .bolus,
                  let amt = ev.amount, amt > 0,
                  ev.timestamp >= dataStart else { return nil }
            return EventHit(date: ev.timestamp, amount: NSDecimalNumber(decimal: amt).doubleValue)
        }
    }

    /// All real carb entries (no FPUs) in the loaded 24 h window.
    private var carbHits: [EventHit] {
        data.carbs.compactMap { c -> EventHit? in
            guard (c.isFPU ?? false) == false, c.carbs > 0 else { return nil }
            let when = c.actualDate ?? c.createdAt
            guard when >= dataStart else { return nil }
            return EventHit(date: when, amount: NSDecimalNumber(decimal: c.carbs).doubleValue)
        }
    }

    /// Snap an event's y-coordinate to the nearest glucose reading so the
    /// marker sits on the curve. Falls back to the in-range mid-point if no
    /// reading is close enough (e.g. event near dataStart with no glucose yet).
    private func glucoseY(at date: Date) -> Double {
        let mid = (lowThreshold + highThreshold) / 2
        let pts = gluPoints
        guard let nearest = pts.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return mid }
        if abs(nearest.date.timeIntervalSince(date)) > 15 * 60 { return mid }
        return nearest.value
    }

    /// Dot sizes scale with dose — SMBs (~0.1 E) stay subtle, meal boluses
    /// grow visibly. Carbs use a flatter slope since gram amounts can run high.
    private func bolusSymbolSize(_ amount: Double) -> Double {
        min(150, max(20, 20 + amount * 22))
    }

    private func carbSymbolSize(_ amount: Double) -> Double {
        min(140, max(20, 20 + amount * 1.4))
    }

    /// Approximate vertical pixel offset expressed in y-domain units.
    /// Chart height is fixed at 150 pt; y-domain spans yHigh − yLow.
    /// Lets us nudge bolus/carb dots above/below the glucose curve so they
    /// don't sit directly on top of it.
    private func yOffset(pixels: Double) -> Double {
        pixels * (yHigh - yLow) / 150.0
    }

    /// Bolus / carb dots both ride the live glucose status color (green /
    /// amber / red) so the chart stays in the Aurora monochrome system.
    /// Boli render slightly stronger than carbs to keep the two types
    /// distinguishable at a glance.
    private var bolusDotColor: Color { status.main.opacity(0.75) }
    private var carbDotColor: Color { status.main.opacity(0.40) }

    // MARK: - Basal segments

    private struct BasalSegment: Identifiable {
        var id: Date { start }
        let start: Date
        let end: Date
        let rate: Double
    }

    private var basalMaxRate: Double {
        let profileMax = data.basalProfile
            .map { NSDecimalNumber(decimal: $0.rate).doubleValue }.max() ?? 0
        let tempMax = data.tempBasals.compactMap(\.rate)
            .map { NSDecimalNumber(decimal: $0).doubleValue }.max() ?? 0
        let pumpMax = NSDecimalNumber(decimal: data.maxBasal).doubleValue
        return max(0.5, max(profileMax, max(tempMax, pumpMax)))
    }

    private var basalBandHeight: Double { (yHigh - yLow) * 0.16 }
    private var basalBaselineY: Double { yHigh - basalBandHeight }

    /// The active rate timeline across the visible window — temp basals where
    /// present, profile rate in the gaps, clamped to `now`.
    /// Logic mirrors BreatheMainChart so the visualization stays consistent
    /// between skins.
    private var basalSegments: [BasalSegment] {
        // 1. Pair tempBasal + tempBasalDuration events into segments.
        var temps: [BasalSegment] = []
        for window in data.tempBasals.windows(ofCount: 2) {
            let arr = Array(window)
            guard arr.count == 2,
                  arr[0].type == .tempBasal,
                  arr[1].type == .tempBasalDuration else { continue }
            let duration = Double(arr[1].durationMin ?? 0) * 60
            guard duration > 0 else { continue }
            let rate = NSDecimalNumber(decimal: arr[0].rate ?? 0).doubleValue
            temps.append(BasalSegment(
                start: arr[0].timestamp,
                end: arr[0].timestamp.addingTimeInterval(duration),
                rate: rate
            ))
        }
        // 2. Truncate each temp at the next temp's start (cancellations).
        var truncated: [BasalSegment] = []
        for (i, t) in temps.enumerated() {
            let nextStart = (i + 1 < temps.count) ? temps[i + 1].start : .distantFuture
            let end = min(t.end, nextStart)
            if end > t.start {
                truncated.append(BasalSegment(start: t.start, end: end, rate: t.rate))
            }
        }
        // 3. Walk the window, filling gaps between temps with profile rate.
        let nowDate = now
        var segments: [BasalSegment] = []
        var cursor = dataStart
        for t in truncated where t.end > dataStart && t.start < xEnd {
            let tStart = max(t.start, dataStart)
            if cursor < tStart {
                appendProfileSegments(from: cursor, to: min(tStart, nowDate), into: &segments)
            }
            let tEnd = min(t.end, xEnd)
            segments.append(BasalSegment(start: tStart, end: tEnd, rate: t.rate))
            cursor = tEnd
        }
        if cursor < nowDate {
            appendProfileSegments(from: cursor, to: nowDate, into: &segments)
        }
        // 4. Merge adjacent same-rate segments.
        return mergeBasalSegments(segments)
    }

    private func appendProfileSegments(
        from start: Date,
        to end: Date,
        into segments: inout [BasalSegment]
    ) {
        guard start < end, !data.basalProfile.isEmpty else { return }
        let sorted = data.basalProfile.sorted { $0.minutes < $1.minutes }
        let cal = Calendar.current
        var cursor = start
        while cursor < end {
            let dayStart = cal.startOfDay(for: cursor)
            let minutes = Int(cursor.timeIntervalSince(dayStart) / 60)
            let idx = sorted.lastIndex { $0.minutes <= minutes } ?? 0
            let rate = NSDecimalNumber(decimal: sorted[idx].rate).doubleValue
            let nextMinutes = (idx + 1 < sorted.count)
                ? sorted[idx + 1].minutes
                : 24 * 60 + sorted[0].minutes
            let nextSwitch = dayStart.addingTimeInterval(TimeInterval(nextMinutes * 60))
            let segEnd = min(end, nextSwitch)
            segments.append(BasalSegment(start: cursor, end: segEnd, rate: rate))
            cursor = segEnd
        }
    }

    private func mergeBasalSegments(_ segs: [BasalSegment]) -> [BasalSegment] {
        var merged: [BasalSegment] = []
        for s in segs where s.end > s.start {
            if let last = merged.last,
               abs(last.rate - s.rate) < 0.0001,
               abs(last.end.timeIntervalSince(s.start)) < 1
            {
                merged.removeLast()
                merged.append(BasalSegment(start: last.start, end: s.end, rate: s.rate))
            } else {
                merged.append(s)
            }
        }
        return merged
    }

    // MARK: - Hours switch

    private static let hourOptions: [Int] = [3, 6, 12, 24]

    private func cycleHours() {
        let i = Self.hourOptions.firstIndex(of: data.screenHours) ?? 0
        data.screenHours = Self.hourOptions[(i + 1) % Self.hourOptions.count]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            hoursButton
            chartView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .auroraGlass(radius: 28)
        .onAppear { snapScrollToNow() }
        .onChange(of: data.screenHours) { _ in snapScrollToNow() }
    }

    /// Anchor the scroll window so `now` sits at the right edge with the
    /// 1 h future lane visible. Triggered on appear and on hours switch.
    private func snapScrollToNow() {
        scrollPosition = Date().addingTimeInterval(-Double(data.screenHours) * 3600)
    }

    private var hoursButton: some View {
        HStack {
            if let openDataTable = onOpenDataTable {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    openDataTable()
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AuroraPalette.textPrimary(scheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().stroke(AuroraPalette.hairline(scheme), lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Behandlungen"))
            }

            chartLegend

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cycleHours()
            }) {
                Text("\(data.screenHours)h")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(AuroraPalette.hairline(scheme), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// Compact legend that sits in the chart header next to the data-table
    /// button, on the same row as the hours switch. Only shows the entries
    /// whose toggle is on, so the legend stays empty when no markers render.
    @ViewBuilder private var chartLegend: some View {
        if displayCarbs || displayBoluses {
            HStack(spacing: 10) {
                if displayBoluses {
                    legendItem(label: "Boli", color: bolusDotColor)
                }
                if displayCarbs {
                    legendItem(label: "Carbs", color: carbDotColor)
                }
            }
            .padding(.leading, 8)
        }
    }

    private func legendItem(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
        }
    }

    private var chartView: some View {
        let pts = gluPoints
        let basals = displayBasal ? basalSegments : []
        let basalMax = basalMaxRate
        let basalBand = basalBandHeight
        let basalBase = basalBaselineY
        let selGlu = selectedGluPoint
        let selBolus = selectedBolus
        let selCarb = selectedCarb

        return Chart {
            // 0. Target band — soft Status-Color wash between low and high
            //    thresholds spanning the full timeline.
            RectangleMark(
                xStart: .value("tbs", dataStart),
                xEnd: .value("tbe", xEnd),
                yStart: .value("tbl", lowThreshold),
                yEnd: .value("tbh", highThreshold)
            )
            .foregroundStyle(status.main.opacity(scheme == .dark ? 0.08 : 0.06))

            // 1. Basal bars — hang from top edge of plot, length = rate / maxRate
            if displayBasal {
                ForEach(basals) { s in
                    if s.rate > 0 {
                        RectangleMark(
                            xStart: .value("bs", s.start),
                            xEnd: .value("be", s.end),
                            yStart: .value("by1", yHigh),
                            yEnd: .value("by2", yHigh - (s.rate / basalMax) * basalBand)
                        )
                        .foregroundStyle(status.main.opacity(scheme == .dark ? 0.32 : 0.26))
                    }
                }
                RuleMark(y: .value("bb", basalBase))
                    .lineStyle(StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                    .foregroundStyle(AuroraPalette.hairline(scheme))
            }

            // 2. Temp-target bars (height = target range, width = duration).
            ForEach(tempTargetSpans) { s in
                RectangleMark(
                    xStart: .value("ts", s.start),
                    xEnd: .value("te", s.end),
                    yStart: .value("yl", s.yLow),
                    yEnd: .value("yh", s.yHigh)
                )
                .foregroundStyle(s.color.opacity(0.28))
            }

            // 3. Profile-override bars — thin stripe centered on the target.
            ForEach(overrideSpans) { s in
                RectangleMark(
                    xStart: .value("ovs", s.start),
                    xEnd: .value("ove", s.end),
                    yStart: .value("ovl", s.yLow),
                    yEnd: .value("ovh", s.yHigh)
                )
                .foregroundStyle(s.color.opacity(0.45))
            }

            // 4. Target threshold hairlines (labels are rendered via chartYAxis
            //    so they don't get clipped by the plot's trailing edge).
            RuleMark(y: .value("low", lowThreshold))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 6]))
                .foregroundStyle(AuroraPalette.hairline(scheme))
            RuleMark(y: .value("high", highThreshold))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 6]))
                .foregroundStyle(AuroraPalette.hairline(scheme))

            // 3. Optional vertical hour grid (UIUX toggle: data.displayXgridLines)
            if data.displayXgridLines {
                ForEach(hourGridDates, id: \.self) { d in
                    RuleMark(x: .value("hour", d))
                        .lineStyle(StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                        .foregroundStyle(AuroraPalette.hairline(scheme).opacity(0.7))
                }
            }

            // 4. Now vertical line
            RuleMark(x: .value("now", now))
                .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
                .foregroundStyle(AuroraPalette.textFaint(scheme))

            // 4b. Area fill under the glucose curve — single Status-Color
            //     series so the wash stays cohesive even where the line itself
            //     turns grey (out-of-range). Fades top → bottom.
            ForEach(pts) { p in
                AreaMark(
                    x: .value("t", p.date),
                    yStart: .value("yLow", yLow),
                    yEnd: .value("g", p.value),
                    series: .value("series", "area")
                )
                .interpolationMethod(.linear)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            status.main.opacity(scheme == .dark ? 0.32 : 0.24),
                            status.main.opacity(0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            // 5. Glucose line — split at every threshold crossing so the
            //    in-range parts carry the live status color while out-of-range
            //    stretches render in neutral grey. Each segment gets its own
            //    series tag so SwiftUI Charts joins it cleanly (no phantom
            //    connecting strokes between segments).
            ForEach(lineSegments) { seg in
                ForEach(seg.points) { p in
                    LineMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value),
                        series: .value("series", "glow-\(seg.id)")
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        (seg.inRange ? status.main : AuroraPalette.textMuted(scheme))
                            .opacity(scheme == .dark ? 0.22 : 0.18)
                    )
                }
            }
            ForEach(lineSegments) { seg in
                ForEach(seg.points) { p in
                    LineMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value),
                        series: .value("series", "glucose-\(seg.id)")
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        (seg.inRange ? status.main : AuroraPalette.textMuted(scheme))
                            .opacity(0.95)
                    )
                }
            }

            // 5b. Reduced forecast line — single combined prediction in the
            //     future lane, faint status color, dashed so it reads as a
            //     projection rather than a measured reading.
            ForEach(predictionPoints) { p in
                LineMark(
                    x: .value("t", p.date),
                    y: .value("g", p.value),
                    series: .value("series", "prediction")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [3, 4]))
                .foregroundStyle(predictionColor)
            }

            // 6. (No per-reading dots — the segmented line already
            //     communicates in-range vs out-of-range, and stray dots
            //     fight visually with the calm hero line.)

            // 6b. Permanent carb dots — sit ~20 pt BELOW the curve.
            if displayCarbs {
                let drop = yOffset(pixels: 20)
                ForEach(carbHits, id: \.date) { c in
                    PointMark(
                        x: .value("t", c.date),
                        y: .value("g", max(yLow, glucoseY(at: c.date) - drop))
                    )
                    .symbol(.circle)
                    .symbolSize(carbSymbolSize(c.amount))
                    .foregroundStyle(carbDotColor)
                }
            }

            // 6c. Permanent bolus dots — sit ~20 pt ABOVE the curve.
            if displayBoluses {
                let lift = yOffset(pixels: 20)
                ForEach(bolusHits, id: \.date) { b in
                    PointMark(
                        x: .value("t", b.date),
                        y: .value("g", min(yHigh, glucoseY(at: b.date) + lift))
                    )
                    .symbol(.circle)
                    .symbolSize(bolusSymbolSize(b.amount))
                    .foregroundStyle(bolusDotColor)
                }
            }

            // 7. Finger-drag selection — vertical guide + larger highlight dot
            if let sel = selGlu {
                RuleMark(x: .value("selected", sel.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(status.main.opacity(0.6))
                PointMark(
                    x: .value("t", sel.date),
                    y: .value("g", sel.value)
                )
                .symbolSize(90)
                .foregroundStyle(status.main)
            }

            // 8. Selected bolus / carb indicators near the curve
            if let b = selBolus {
                PointMark(
                    x: .value("t", b.date),
                    y: .value("g", lowThreshold + (highThreshold - lowThreshold) * 0.95)
                )
                .symbol(.circle)
                .symbolSize(36 + b.amount * 8)
                .foregroundStyle(AuroraPalette.drop(scheme))
            }
            if let c = selCarb {
                PointMark(
                    x: .value("t", c.date),
                    y: .value("g", lowThreshold + (highThreshold - lowThreshold) * 0.05)
                )
                .symbol(.circle)
                .symbolSize(36 + c.amount * 1.4)
                .foregroundStyle(AuroraPalette.carbs(scheme))
            }
        }
        .chartXSelection(value: $selectedChartDate)
        .chartXScale(domain: dataStart ... xEnd)
        .chartYScale(domain: yLow ... yHigh)
        .chartScrollableAxes(isScrollable ? .horizontal : [])
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartScrollPosition(x: $scrollPosition)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: hourStride)) { _ in
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textFaint(scheme))
            }
        }
        .chartYAxis {
            // Threshold labels rendered as a real trailing axis so they
            // sit inside the plot's reserved trailing inset — no more "18"
            // clipped to "180".
            AxisMarks(position: .trailing, values: [lowThreshold, highThreshold]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatY(v))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AuroraPalette.textFaint(scheme))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame.map({ geo[$0] }) {
                    // Bright "now" dot at the latest reading — outside the
                    // Chart {} block so it doesn't introduce another series
                    // SwiftUI Charts could mis-join with the line.
                    if let last = pts.last,
                       let xCoord = proxy.position(forX: last.date),
                       let yCoord = proxy.position(forY: last.value)
                    {
                        nowDot
                            .position(
                                x: plotFrame.origin.x + xCoord,
                                y: plotFrame.origin.y + yCoord
                            )
                    }

                    // Selection card (BG/Bolus/Carb) — anchored to touch
                    if let target = selectedChartDate,
                       let sel = selectedGluPoint,
                       let xCoord = proxy.position(forX: target)
                    {
                        selectionCard(point: sel, bolus: selectedBolus, carb: selectedCarb)
                            .fixedSize()
                            .background(
                                GeometryReader { cardGeo in
                                    Color.clear.preference(
                                        key: CardSizeKey.self,
                                        value: cardGeo.size
                                    )
                                }
                            )
                            .modifier(SelectionCardPositioner(
                                anchorX: plotFrame.origin.x + xCoord,
                                plotWidth: plotFrame.width,
                                plotTop: plotFrame.origin.y
                            ))
                    }
                }
            }
        }
        .frame(height: 150)
    }

    /// Bright "now" dot anchored to the latest glucose reading.
    /// White core + status-color halo + status-color stroke.
    private var nowDot: some View {
        ZStack {
            Circle()
                .fill(status.main.opacity(0.35))
                .frame(width: 24, height: 24)
                .blur(radius: 4)
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(status.main, lineWidth: 2.5))
        }
    }

    // MARK: - Selection popover

    private func selectionCard(point: GluPoint, bolus: EventHit?, carb: EventHit?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(status.main).frame(width: 7, height: 7)
                Text(formatY(point.value) + " \(isMmolL ? "mmol/L" : "mg/dL")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
            }
            Text(timeFormatter.string(from: point.date))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
            if let b = bolus {
                HStack(spacing: 4) {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(String(format: "%.2f E", b.amount).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(AuroraPalette.drop(scheme))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(AuroraPalette.drop(scheme).opacity(0.18)))
            }
            if let c = carb {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(Int(c.amount)) g")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(AuroraPalette.carbs(scheme))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(AuroraPalette.carbs(scheme).opacity(0.18)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AuroraPalette.hairline(scheme), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
        )
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    private func formatY(_ v: Double) -> String {
        if isMmolL {
            return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
        }
        return "\(Int(v))"
    }
}

/// Tracks the rendered size of the selection card so the positioner can
/// clamp it inside the plot.
private struct CardSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Positions the selection card above the touched data point, clamped so it
/// never spills off the chart edges. Lays the card just above the plot's top.
private struct SelectionCardPositioner: ViewModifier {
    let anchorX: CGFloat
    let plotWidth: CGFloat
    let plotTop: CGFloat

    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        let half = size.width / 2
        let minX = half + 4
        let maxX = plotWidth - half - 4
        let x = max(minX, min(maxX, anchorX))
        let y = plotTop + size.height / 2 + 2
        return content
            .onPreferenceChange(CardSizeKey.self) { size = $0 }
            .position(x: x, y: y)
    }
}
