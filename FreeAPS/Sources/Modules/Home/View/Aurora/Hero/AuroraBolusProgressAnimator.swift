import QuartzCore
import SwiftUI

/// Turns the pump's coarse, segment-by-segment bolus progress into a smooth,
/// continuously advancing fill — the calm crawl of an iOS software update.
///
/// The pump only reports `percentComplete` in jumps. Because we know the total
/// dose from the start, we estimate the delivery speed from the samples we have
/// already received and keep advancing the fill at that speed *between* samples,
/// instead of snapping from one segment to the next. The fill never moves
/// backwards and eases to a rest just shy of full, completing only once the pump
/// confirms the bolus is done.
///
/// This smooths the *bar geometry* only — the numeric "delivered" readout stays
/// tied to the real pump value, so we never claim to have delivered more insulin
/// than actually went in.
@MainActor final class AuroraBolusProgressAnimator: ObservableObject {
    /// Smoothed fill fraction, 0...1, driven at display refresh rate.
    @Published private(set) var fraction: Double = 0

    /// Conservative fallback delivery rate (U/s) used to seed the very first
    /// frames, before enough real samples exist to measure the true speed.
    /// Deliberately slow (~Omnipod pulse cadence) so a fast pump's real samples
    /// pull us *forward*, never leaving the bar stranded ahead of reality.
    private static let nominalRate = 0.025

    /// Duration of the closing fill once the pump confirms completion. Kept
    /// shorter than the ~0.5s overlay-dismiss delay so the bar visibly reaches
    /// 100% first.
    private static let finishDuration: TimeInterval = 0.35

    private var link: CADisplayLink?
    private var startDate: Date?
    private var lastReal: Double = 0
    private var lastRealDate: Date?
    private var speed: Double = 0 // fraction per second, monotonic
    private var finishStart: Date? // set when completion fill begins
    private var finishFrom: Double = 0 // fraction at the moment completion began

    /// Feed the truthful pump fraction (`nil` once no bolus is in flight) and
    /// the total dose, used to seed an initial crawl speed.
    func sync(real: Double?, total: Double?) {
        guard let real, real >= 0 else { reset()
            return }
        let now = Date()

        if startDate == nil {
            startDate = now
            fraction = 0
            // Seed a slow initial crawl so the bar moves from the first frame.
            if let total, total > 0 {
                speed = Self.nominalRate / total
            }
        }

        if real > lastReal {
            lastReal = min(1, real)
            lastRealDate = now
            // Re-measure the average speed since the start of delivery, and only
            // ever let the estimate rise — a single slow sample must not stall
            // the crawl we have already shown.
            if let start = startDate {
                let elapsed = now.timeIntervalSince(start)
                if elapsed > 0.3 {
                    speed = max(speed, lastReal / elapsed)
                }
            }
        }

        startLink()
    }

    private func startLink() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(step))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func step() {
        guard let start = startDate else { return }

        // Completion confirmed by the pump → ease the remaining gap to 100%
        // quickly, so the bar visibly fills before the overlay is dismissed
        // (~0.5s later) instead of vanishing mid-crawl around the 97% rest point.
        if lastReal >= 1 {
            if finishStart == nil {
                finishStart = Date()
                finishFrom = fraction
            }
            let t = min(1, Date().timeIntervalSince(finishStart!) / Self.finishDuration)
            let eased = 1 - pow(1 - t, 2) // ease-out
            fraction = max(fraction, finishFrom + (1 - finishFrom) * eased)
            if t >= 1 {
                fraction = 1
                stopLink()
            }
            return
        }

        // Pure time-based projection at the measured speed, resting just short of
        // full until the pump confirms completion, so the bar never reports
        // "done" before the insulin is actually in. Monotonic, and always at
        // least the truthful delivered fraction so a real sample that overtakes
        // our estimate simply pulls us forward.
        let elapsed = Date().timeIntervalSince(start)
        let projected = speed > 0 ? speed * elapsed : fraction
        let next = max(fraction, max(min(projected, 0.97), lastReal))
        if next != fraction { fraction = next }
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    private func reset() {
        stopLink()
        startDate = nil
        lastRealDate = nil
        lastReal = 0
        speed = 0
        finishStart = nil
        finishFrom = 0
        // Leave `fraction` where it is so a completed bar fades out full rather
        // than snapping to empty during the overlay's slide-out. The next bolus
        // resets it to 0 via the `startDate == nil` branch in sync(real:total:).
    }
}
