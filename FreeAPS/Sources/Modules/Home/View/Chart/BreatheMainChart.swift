import Algorithms
import Charts
import Foundation
import SwiftUI

extension Home {
    struct BreatheMainChart: View {
        @ObservedObject var data: ChartModel

        /// User-toggleable basal step display (Settings → UIUX). When off, the
        /// segment computation is skipped entirely.
        var displayBasal: Bool = false

        @State private var scrollPosition = Date()
        @State private var selectedChartDate: Date? = nil

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

        /// Glucose reading nearest to the user's current finger position.
        /// `chartXSelection` reports raw chart coordinates, so we snap to
        /// the actual data point so the popover never floats over empty space.
        private var selectedGluPoint: GluPoint? {
            guard let target = selectedChartDate else { return nil }
            return gluPoints.min(by: {
                abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
            })
        }

        // MARK: Bolus / Carbs near selection

        /// Time window (seconds) in which a bolus or carb event counts as
        /// "near" the finger and is shown in the popover / lit on the chart.
        private static let nearWindow: TimeInterval = 3 * 60

        private struct EventHit {
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

        /// All bolus events within the loaded 24 h window — drawn as small
        /// permanent dots near the top of the plot.
        private var bolusHits: [EventHit] {
            data.boluses.compactMap { ev -> EventHit? in
                guard ev.type == .bolus,
                      let amt = ev.amount, amt > 0,
                      ev.timestamp >= dataStart else { return nil }
                return EventHit(date: ev.timestamp, amount: NSDecimalNumber(decimal: amt).doubleValue)
            }
        }

        /// All real carb entries within the loaded 24 h window — drawn as
        /// small permanent dots near the bottom of the plot.
        private var carbHits: [EventHit] {
            data.carbs.compactMap { c -> EventHit? in
                guard (c.isFPU ?? false) == false, c.carbs > 0 else { return nil }
                let when = c.actualDate ?? c.createdAt
                guard when >= dataStart else { return nil }
                return EventHit(date: when, amount: NSDecimalNumber(decimal: c.carbs).doubleValue)
            }
        }

        // MARK: Bolus / Carb dot placement along the glucose curve

        /// Vertical offset (in displayed glucose units) between the glucose
        /// curve and the bolus / carb dots. Mirrors `insulinOffset` /
        /// `carbOffset` from the original MainChart, but expressed in
        /// data-space so the dots ride the curve at any zoom level.
        private var bolusCurveOffset: Double { isMmolL ? 1.0 : 17 }
        private var carbCurveOffset: Double { isMmolL ? 1.0 : 17 }

        /// A bolus / carb event with its pre-computed Y position along the curve.
        /// Pre-computing matters because the Chart body re-renders on every
        /// finger movement during scrub — per-dot O(N) glucose scans there
        /// caused visible stutter.
        struct PlacedEvent: Identifiable {
            var id: Date { date }
            let date: Date
            let amount: Double
            let y: Double
        }

        /// Binary-search linear interpolation of the glucose value at `date`
        /// between the two surrounding readings. `pts` must be sorted by date
        /// (the existing `gluPoints` array is, since the LineMark relies on
        /// chronological order).
        private func interpolate(_ date: Date, in pts: [GluPoint]) -> Double? {
            guard let first = pts.first, let last = pts.last else { return nil }
            if date <= first.date { return first.value }
            if date >= last.date { return last.value }
            var lo = 0
            var hi = pts.count - 1
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if pts[mid].date <= date { lo = mid } else { hi = mid }
            }
            let a = pts[lo]
            let b = pts[hi]
            let span = b.date.timeIntervalSince(a.date)
            if span <= 0 { return a.value }
            let t = date.timeIntervalSince(a.date) / span
            return a.value + (b.value - a.value) * t
        }

        private func placeBoluses(in pts: [GluPoint]) -> [PlacedEvent] {
            let margin = isMmolL ? 0.2 : 4.0
            let fallback = yDomain.upperBound - (yDomain.upperBound - yDomain.lowerBound) * 0.1
            return bolusHits.map { b in
                let g = interpolate(b.date, in: pts) ?? fallback
                let y = min(yDomain.upperBound - margin, g + bolusCurveOffset)
                return PlacedEvent(date: b.date, amount: b.amount, y: y)
            }
        }

        private func placeCarbs(in pts: [GluPoint]) -> [PlacedEvent] {
            let margin = isMmolL ? 0.2 : 4.0
            let fallback = yDomain.lowerBound + (yDomain.upperBound - yDomain.lowerBound) * 0.1
            return carbHits.map { c in
                let g = interpolate(c.date, in: pts) ?? fallback
                let y = max(yDomain.lowerBound + margin, g - carbCurveOffset)
                return PlacedEvent(date: c.date, amount: c.amount, y: y)
            }
        }

        /// Dot area (SwiftUI `symbolSize` is area in pt², not diameter).
        /// Tuned so SMBs stay tiny, typical meal boluses are clearly visible,
        /// and very large doses cap out before they take over the plot.
        ///   0.1 U → 16   ·   1 U → 32   ·   3 U → 68   ·   10 U → 194   ·   ≥12 U → 220
        private func bolusSymbolSize(_ amount: Double) -> Double {
            min(220, 14 + amount * 18)
        }

        /// Carb dot area — paced gentler than insulin because gram counts run
        /// an order of magnitude higher.
        ///   10 g → 29   ·   30 g → 59   ·   50 g → 89   ·   100 g → 164   ·   ≥124 g → 200
        private func carbSymbolSize(_ amount: Double) -> Double {
            min(200, 14 + amount * 1.5)
        }

        /// Added on top of the base size when a dot is the scrub-selected one,
        /// so the highlight stays visible even when the base dot is already big.
        private static let selectionBoost: Double = 40

        // MARK: Basal step display

        /// One step in the effective-rate timeline: either a temp basal interval
        /// or a profile-rate gap between temps. Rendered as a thin bar at the
        /// top of the plot, height proportional to `rate`.
        private struct BasalSegment: Identifiable {
            var id: Date { start }
            let start: Date
            let end: Date
            let rate: Double
        }

        /// Top-of-chart band reserved for basal bars, expressed in glucose
        /// y-units (so it shares the same axis as the curve — no second chart
        /// needed). 7 % of the y-range keeps the band visible without eating
        /// the hyperglycemia headroom above 250 mg/dL.
        private var basalBandHeight: Double {
            (yDomain.upperBound - yDomain.lowerBound) * 0.07
        }

        private var basalBaselineY: Double {
            yDomain.upperBound - basalBandHeight
        }

        /// Normalization reference — bars at this rate fill the full band.
        /// Cover profile-max, temp-max, and pump-max to keep extreme temps
        /// inside the band.
        private var basalMaxRate: Double {
            let profileMax = data.basalProfile
                .map { NSDecimalNumber(decimal: $0.rate).doubleValue }.max() ?? 0
            let tempMax = data.tempBasals.compactMap(\.rate)
                .map { NSDecimalNumber(decimal: $0).doubleValue }.max() ?? 0
            let pumpMax = NSDecimalNumber(decimal: data.maxBasal).doubleValue
            return max(0.5, max(profileMax, max(tempMax, pumpMax)))
        }

        /// The active rate timeline across the loaded window: temp basals
        /// where present, profile rate in the gaps. Adjacent equal-rate
        /// segments are merged so the chart only draws ~one mark per change.
        private var basalSegments: [BasalSegment] {
            // 1. Temp intervals from paired (.tempBasal, .tempBasalDuration) events.
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
            //    Profile fills are clamped to `now`: the area right of the live
            //    marker should stay empty unless an active TBR extends into it
            //    (matches Trio/Loop convention; was: drew profile up to xEnd).
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

        // MARK: Target spans (Temp Target / Profile Override)

        /// A horizontal target band — drawn as a translucent rectangle showing
        /// both the requested target (Y) and the chosen duration (X). Mirrors
        /// the temp-target / override bars from the original MainChart.
        private struct TargetSpan: Identifiable {
            let id: String
            let start: Date
            let end: Date
            let yLow: Double
            let yHigh: Double
            let color: Color
        }

        /// Half-thickness of a profile-override bar, in displayed units.
        /// Profile overrides hold a single target value, so we render a thin
        /// stripe centred on the target — same idea as the 6-px-tall bar in
        /// the original MainChart.
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

                // A new entry (even a cancel marker with duration=0) truncates
                // the previous span so two bars don't visually overlap.
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
                // Ensure the bar is visible even when top == bottom (single target).
                let pad = yHigh - yLow < overrideBarHalfHeight * 2 ? overrideBarHalfHeight : 0

                spans.append(TargetSpan(
                    id: "tt-\(start.timeIntervalSince1970)",
                    start: max(start, dataStart),
                    end: min(end, xEnd),
                    yLow: yLow - pad,
                    yHigh: yHigh + pad,
                    color: BreathePalette.daemmer
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
                    color: BreathePalette.flieder
                ))
            }

            // Active profile override — extends to now (or to its scheduled end).
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
                            color: BreathePalette.fliederDeep
                        ))
                    }
                }
            }
            return spans
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

        // MARK: - Header

        private static let hourOptions: [Int] = [3, 6, 12, 24]

        /// Label inside the cycle button — now communicates the selected
        /// range directly, so the redundant heading on the left can go away.
        private var durationLabel: String {
            "\(data.screenHours)h"
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
                Spacer()

                Button(action: cycleHours) {
                    Text(durationLabel)
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
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

        // MARK: - Body

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(spacing: 2) {
                headerRow
                glucoseStave
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: 8, y: 3)
            .padding(.horizontal, 10)
            .onAppear {
                scrollPosition = visibleStart
            }
            .onChange(of: data.screenHours) {
                scrollPosition = now.addingTimeInterval(-Double(data.screenHours) * 3600)
                selectedChartDate = nil
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
            // Snapshot everything once per body call. The Chart re-renders on
            // every scrub-position change, so any per-dot work over gluPoints
            // would stutter — we compute the placements (which include the
            // O(log N) interpolation against the glucose curve) up front.
            let pts = gluPoints
            let placedBoluses = placeBoluses(in: pts)
            let placedCarbs = placeCarbs(in: pts)
            let basalSegs: [BasalSegment] = displayBasal ? basalSegments : []
            let basalMax = basalMaxRate
            let basalBase = basalBaselineY
            let basalBand = basalBandHeight
            let selGlu: GluPoint? = selectedChartDate.flatMap { target in
                pts.min(by: {
                    abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
                })
            }
            let selBolusPlaced: PlacedEvent? = selectedBolus.flatMap { b in
                placedBoluses.first(where: { $0.date == b.date })
            }
            let selCarbPlaced: PlacedEvent? = selectedCarb.flatMap { c in
                placedCarbs.first(where: { $0.date == c.date })
            }

            return Chart {
                // In-range band
                RectangleMark(
                    xStart: .value("start", dataStart),
                    xEnd: .value("end", xEnd),
                    yStart: .value("lo", lowThreshold),
                    yEnd: .value("hi", highThreshold)
                )
                .foregroundStyle(BreathePalette.salbei.opacity(0.12))

                // Basal step bars — hang from the top edge of the plot,
                // length = rate / maxRate. Drawn before threshold rules so
                // the dashed low/high lines stay visually un-interrupted.
                if displayBasal {
                    ForEach(basalSegs) { s in
                        if s.rate > 0 {
                            RectangleMark(
                                xStart: .value("bs", s.start),
                                xEnd: .value("be", s.end),
                                yStart: .value("by1", yDomain.upperBound),
                                yEnd: .value("by2", yDomain.upperBound - (s.rate / basalMax) * basalBand)
                            )
                            .foregroundStyle(BreathePalette.daemmer.opacity(0.32))
                        }
                    }
                    // Faint dashed line marking the bottom edge of the basal band —
                    // i.e. how far bars at the max rate reach. Keeps the zone
                    // visible even when no insulin is active.
                    RuleMark(y: .value("bb", basalBase))
                        .lineStyle(StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                        .foregroundStyle(BreathePalette.daemmer.opacity(0.25))
                }

                // Temp-target bars — height = target range, width = duration.
                ForEach(tempTargetSpans) { s in
                    RectangleMark(
                        xStart: .value("ts", s.start),
                        xEnd: .value("te", s.end),
                        yStart: .value("yl", s.yLow),
                        yEnd: .value("yh", s.yHigh)
                    )
                    .foregroundStyle(s.color.opacity(0.28))
                }

                // Profile-override bars — thin stripe at the target value.
                ForEach(overrideSpans) { s in
                    RectangleMark(
                        xStart: .value("ovs", s.start),
                        xEnd: .value("ove", s.end),
                        yStart: .value("ovl", s.yLow),
                        yEnd: .value("ovh", s.yHigh)
                    )
                    .foregroundStyle(s.color.opacity(0.45))
                }

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
                ForEach(pts) { p in
                    LineMark(
                        x: .value("t", p.date),
                        y: .value("g", p.value)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(BreathePalette.salbei.opacity(0.8))
                }
                ForEach(pts) { p in
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

                // Permanent bolus dots — float just above the glucose curve.
                // Size encodes dose: SMBs stay tiny, meal boluses grow visibly.
                ForEach(placedBoluses) { p in
                    PointMark(
                        x: .value("t", p.date),
                        y: .value("g", p.y)
                    )
                    .symbol(.circle)
                    .symbolSize(bolusSymbolSize(p.amount))
                    .foregroundStyle(BreathePalette.daemmer.opacity(0.6))
                }

                // Permanent carb dots — float just below the glucose curve.
                // Size encodes gram count.
                ForEach(placedCarbs) { p in
                    PointMark(
                        x: .value("t", p.date),
                        y: .value("g", p.y)
                    )
                    .symbol(.circle)
                    .symbolSize(carbSymbolSize(p.amount))
                    .foregroundStyle(BreathePalette.kamilleDeep.opacity(0.6))
                }

                // Finger-drag selection — vertical guide line + larger
                // highlighted dot at the closest glucose reading.
                if let sel = selGlu {
                    RuleMark(x: .value("selected", sel.date))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(sel.color.opacity(0.6))
                    PointMark(
                        x: .value("t", sel.date),
                        y: .value("g", sel.value)
                    )
                    .symbolSize(80)
                    .foregroundStyle(sel.color)
                }

                // Bolus indicator — same dose-scaled size plus a fixed boost
                // so the highlight stays visible even on large boluses.
                if let b = selBolusPlaced {
                    PointMark(
                        x: .value("t", b.date),
                        y: .value("g", b.y)
                    )
                    .symbol(.circle)
                    .symbolSize(bolusSymbolSize(b.amount) + Self.selectionBoost)
                    .foregroundStyle(BreathePalette.daemmer)
                }

                // Carbs indicator — same gram-scaled size plus highlight boost.
                if let c = selCarbPlaced {
                    PointMark(
                        x: .value("t", c.date),
                        y: .value("g", c.y)
                    )
                    .symbol(.circle)
                    .symbolSize(carbSymbolSize(c.amount) + Self.selectionBoost)
                    .foregroundStyle(BreathePalette.kamilleDeep)
                }
            }
            .chartXSelection(value: $selectedChartDate)
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
            // Finger-drag popover — anchored at the top centre of the chart
            // frame, fades in and out with the selection.
            .overlay(alignment: .top) {
                if let sel = selGlu {
                    BreatheGlucosePopover(
                        time: sel.date,
                        value: sel.value,
                        isMmolL: isMmolL,
                        color: sel.color,
                        bolusUnits: selBolusPlaced?.amount,
                        carbsGrams: selCarbPlaced?.amount
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .padding(.top, 2)
                    .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: selGlu?.date)
            .animation(.easeInOut(duration: 0.15), value: selBolusPlaced?.date)
            .animation(.easeInOut(duration: 0.15), value: selCarbPlaced?.date)
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
    }

    // MARK: - Glucose drag-popover

    struct BreatheGlucosePopover: View {
        let time: Date
        let value: Double
        let isMmolL: Bool
        let color: Color
        var bolusUnits: Double? = nil
        var carbsGrams: Double? = nil

        @Environment(\.colorScheme) private var colorScheme

        private var timeStr: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: time)
        }

        private var valueStr: String {
            if isMmolL {
                return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
            }
            return "\(Int(value.rounded()))"
        }

        private var unitStr: String {
            isMmolL ? "mmol/L" : "mg/dL"
        }

        private func bolusStr(_ u: Double) -> String {
            String(format: "%.2f", u).replacingOccurrences(of: ".", with: ",")
        }

        private func carbsStr(_ g: Double) -> String {
            "\(Int(g.rounded()))"
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timeStr)
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(color)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(valueStr)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(.primary)
                        Text(unitStr)
                            .font(.system(size: 9, weight: .regular, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                if bolusUnits != nil || carbsGrams != nil {
                    HStack(spacing: 8) {
                        if let u = bolusUnits {
                            HStack(spacing: 3) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(BreathePalette.daemmer)
                                Text("\(bolusStr(u)) E")
                                    .font(.system(size: 10, weight: .regular, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                        if let g = carbsGrams {
                            HStack(spacing: 3) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(BreathePalette.kamilleDeep)
                                Text("\(carbsStr(g)) g")
                                    .font(.system(size: 10, weight: .regular, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .light ? BreathePalette.dunstLight : BreathePalette.dunstDark)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(color, lineWidth: 1.5)
                    )
            }
        }
    }
}
