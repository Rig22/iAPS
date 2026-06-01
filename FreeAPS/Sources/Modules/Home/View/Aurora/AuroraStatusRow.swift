import SwiftUI

/// Loop status — drives the dot color in `AuroraStatusRow`.
/// Intentionally separate from glucose status so the user can't
/// confuse "low BG" with "loop error".
enum AuroraLoopStatus {
    case ok // recent loop, no error → calm green
    case looping // a loop is currently running → cyan
    case stale // loop too old → amber
    case error // last loop failed → red

    var color: Color {
        switch self {
        case .ok: return Color(red: 90 / 255, green: 200 / 255, blue: 130 / 255) // calm green, different hue from status.inMain
        case .looping: return Color(red: 90 / 255, green: 200 / 255, blue: 250 / 255) // #5AC8FA
        case .stale: return Color(red: 255 / 255, green: 176 / 255, blue: 32 / 255)
        case .error: return Color(red: 255 / 255, green: 77 / 255, blue: 109 / 255)
        }
    }
}

/// Top row of the Home screen — sensor age on the left, loop status on the right.
///
/// The dot color is driven by `loop`, NOT by glucose, to avoid making the user
/// read a red dot as "low BG" when it really means "loop error".
///
/// The right-hand "Loop · vor X Min" block is interactive:
/// - tap          → `onTapLoop`           (typically opens a status popup)
/// - long-press   → `onLongPressLoop`     (typically triggers `state.runLoop()`)
/// - `isLooping`  → renders a small spinner overlay so the user can see when a
///                  loop is actually in flight
struct AuroraStatusRow: View {
    let sensorDaysCaption: String? // e.g. "6 Tg"
    let loopCaption: String // e.g. "Loop · vor 1 Min"
    let loop: AuroraLoopStatus
    var isLooping: Bool = false
    var onTapLoop: (() -> Void)? = nil
    var onLongPressLoop: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            // Left — sensor
            if let caption = sensorDaysCaption {
                HStack(spacing: 6) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 12, weight: .semibold))
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AuroraPalette.textMuted(scheme))
            }

            Spacer()

            // Right — loop (interactive)
            HStack(spacing: 8) {
                Text(loopCaption)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))

                ZStack {
                    Circle()
                        .fill(loop.color)
                        .frame(width: 8, height: 8)
                        .shadow(color: loop.color.opacity(0.5), radius: 6, x: 0, y: 0)
                    if isLooping {
                        // Subtle pulsing ring around the dot while a loop runs.
                        Circle()
                            .stroke(loop.color.opacity(0.6), lineWidth: 1)
                            .frame(width: 16, height: 16)
                            .scaleEffect(isLooping ? 1.4 : 1.0)
                            .opacity(isLooping ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                value: isLooping
                            )
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            .padding(.leading, 12)
            .onTapGesture {
                guard let onTapLoop = onTapLoop else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapLoop()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                guard let onLongPressLoop = onLongPressLoop else { return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onLongPressLoop()
            }
        }
    }
}
