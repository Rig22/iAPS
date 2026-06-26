import CGMBLEKit
import Foundation
import G7SensorKit
import LibreTransmitter
import LoopKit
import MedtrumKit
import MinimedKit
import MockKit
import NightscoutRemoteCGM
import OmnipodKit

enum KnownPlugins {
    static func allowCalibrations(for cgmManager: CGMManager) -> Bool {
        cgmManager.pluginIdentifier == LibreTransmitterManagerV3.pluginIdentifier
    }

    static func glucoseUploadingAvailable(for cgmManager: CGMManager) -> Bool {
        switch cgmManager.pluginIdentifier {
        case MockCGMManager.pluginIdentifier: return false
        case NightscoutRemoteCGM.pluginIdentifier: return false
        default: return true
        }
    }

    static func cgmExpirationByPluginIdentifier(_ cgmManager: CGMManager?) -> TimeInterval? {
        guard let cgmManager else { return nil }
        let secondsOfDay = 8.64E4

        return switch cgmManager.pluginIdentifier {
        case G6CGMManager.pluginIdentifier: 10 * secondsOfDay
        case G7CGMManager.pluginIdentifier: 10.5 * secondsOfDay
        case LibreTransmitterManagerV3.pluginIdentifier: libreExpirationSeconds
        case MinimedPumpManager.pluginIdentifier: 6 * secondsOfDay
        default: nil
        }
    }

    static var libreExpirationSeconds: TimeInterval? {
        guard let maxAge = UserDefaults.standard.preSelectedSensor?.maxAge, maxAge > 0 else {
            return nil
        }
        return TimeInterval(maxAge * 60) // Convert minutes to seconds
    }

    static func sessionStart(cgmManager: CGMManager) -> Date? {
        switch cgmManager.pluginIdentifier {
        case G5CGMManager.pluginIdentifier:
            return (cgmManager as? G5CGMManager)?.latestReading?.sessionStartDate
        case G6CGMManager.pluginIdentifier:
            return (cgmManager as? G6CGMManager)?.latestReading?.sessionStartDate
        case G7CGMManager.pluginIdentifier:
            return (cgmManager as? G7CGMManager)?.sensorFinishesWarmupAt
        case LibreTransmitterManagerV3.pluginIdentifier:
            return (cgmManager as? LibreTransmitterManagerV3)?.sensorInfoObservable.activatedAt
        default:
            return nil
        }
    }

    static func appURLByPluginIdentifier(pluginIdentifier: String) -> URL? {
        switch pluginIdentifier {
        case G5CGMManager.pluginIdentifier:
            URL(string: "dexcomgcgm://")!
        case G6CGMManager.pluginIdentifier:
            URL(string: "dexcomg6://")!
        case G7CGMManager.pluginIdentifier:
            URL(string: "dexcomg7://")!
        default: nil
        }
    }

    static func cgmIdForStatistics(for cgmManager: CGMManager?) -> String? {
        guard let cgmManager else { return nil }

        switch cgmManager.pluginIdentifier {
        case G5CGMManager.pluginIdentifier: return CGMType.dexcomG5.rawValue
        case G6CGMManager.pluginIdentifier: return CGMType.dexcomG6.rawValue
        case G7CGMManager.pluginIdentifier: return CGMType.dexcomG7.rawValue
        case LibreTransmitterManagerV3.pluginIdentifier: return CGMType.libreTransmitter.rawValue
        case NightscoutRemoteCGM.pluginIdentifier: return CGMType.nightscout.rawValue
        case MockCGMManager.pluginIdentifier: return CGMType.simulator.rawValue
        case MinimedPumpManager.pluginIdentifier: return CGMType.enlite.rawValue
        case AppGroupCGM.pluginIdentifier:
            guard let cgmManager = cgmManager as? AppGroupCGM else {
                return nil
            }
            return cgmManager.appGroupSource.latestReadingFrom?.rawValue ??
                cgmManager.appGroupSource.latestReadingFromOther
        default: return cgmManager.pluginIdentifier
        }
    }

    static func isManualTempBasalActive(_ pumpManager: PumpManager) -> Bool? {
        guard case let .tempBasal(dose) = pumpManager.status.basalDeliveryState else { return false }
        return !(dose.automatic ?? true)
    }

    /// Omnipod's `podState` as a raw dictionary, read via the base `PumpManager`
    /// protocol's `rawState` instead of `pumpManager as? OmniPumpManager`.
    /// The Omnipod driver is loaded from a plugin bundle, so a typed cast to the
    /// statically-linked `OmniPumpManager` fails at runtime (two distinct type
    /// identities) — every reservoir/expiry read silently returned nil and the
    /// pump tile fell back to a stale stored reservoir with no remaining time.
    /// `rawState` works regardless of where the type was loaded from.
    private static func omnipodPodState(_ pumpManager: PumpManager) -> [String: Any]? {
        pumpManager.rawState["podState"] as? [String: Any]
    }

    static func pumpActivationDate(_ pumpManager: PumpManager) -> Date? {
        switch pumpManager.pluginIdentifier {
        case MedtrumPumpManager.pluginIdentifier:
            return (pumpManager as? MedtrumPumpManager)?.state.patchActivatedAt
        case OmniPumpManager.pluginIdentifier:
            return omnipodPodState(pumpManager)?["activatedAt"] as? Date
        default: return nil
        }
    }

    static func pumpExpirationDate(_ pumpManager: PumpManager) -> Date? {
        switch pumpManager.pluginIdentifier {
        case MedtrumPumpManager.pluginIdentifier:
            // Report the grace-period start (nominal expiry) rather than
            // patchExpiresAt (= lifespan + grace, the hard end), keeping Medtrum
            // in line with Omnipod's podState.expiresAt. Both pumps then expose a
            // nominal expiry with an 8 h grace window after it, which the Aurora
            // pump badge surfaces as a "Grace" countdown.
            return (pumpManager as? MedtrumPumpManager)?.state.patchGracePeriodFrom
        case OmniPumpManager.pluginIdentifier:
            return omnipodPodState(pumpManager)?["expiresAt"] as? Date
        default: return nil
        }
    }

    static func pumpReservoir(_ pumpManager: PumpManager) -> Decimal? {
        switch pumpManager.pluginIdentifier {
        case OmniPumpManager.pluginIdentifier:
            // Pods can't report an exact level above 50 U: reservoirLevel is then
            // nil or the "above threshold" magic number — both mean "> 50 U", for
            // which we substitute the sentinel (rendered as a full pod). At/below
            // 50 U the pod reports the real remaining units.
            let measurements = omnipodPodState(pumpManager)?["lastInsulinMeasurements"] as? [String: Any]
            guard let level = measurements?["reservoirLevel"] as? Double, level <= 50.0 else {
                return Decimal(0xDEAD_BEEF)
            }
            return Decimal(level)
        case MedtrumPumpManager.pluginIdentifier:
            guard let reservoir = (pumpManager as? MedtrumPumpManager)?.state.reservoir else { return nil }
            return Decimal(reservoir)
        default: return nil
        }
    }

    /// Full reservoir capacity (U100-equivalent) for pumps whose level is drawn
    /// as a filled silhouette in the Aurora pump tile. The Medtrum Nano ships as
    /// a 200 U and a 300 U variant (model MD8301); mirroring the driver's own
    /// `pumpReservoirCapacity` here keeps the logic on the app side so MedtrumKit
    /// upstream updates don't clobber it. Omnipod holds 200 U; `nil` for pumps
    /// that keep the plain cylinder icon (Dana, Medtronic).
    static func pumpReservoirCapacity(_ pumpManager: PumpManager) -> Decimal? {
        switch pumpManager.pluginIdentifier {
        case OmniPumpManager.pluginIdentifier:
            return 200
        case MedtrumPumpManager.pluginIdentifier:
            return (pumpManager as? MedtrumPumpManager)?.state.model == "MD8301" ? 300 : 200
        default: return nil
        }
    }

    static func cgmInfo(for cgmManager: CGMManager) -> GlucoseSourceInfo? {
        switch cgmManager.pluginIdentifier {
        case G5CGMManager.pluginIdentifier:
            guard let cgmManager = cgmManager as? G5CGMManager else { return nil }
            let description = "Dexcom tramsmitter ID: \(cgmManager.transmitter.ID)"
            return GlucoseSourceInfo(description: description, transmitterBattery: nil)

        case G6CGMManager.pluginIdentifier:
            guard let cgmManager = cgmManager as? G6CGMManager else { return nil }
            let description = "Dexcom tramsmitter ID: \(cgmManager.transmitter.ID)"
            return GlucoseSourceInfo(description: description, transmitterBattery: nil)

        case LibreTransmitterManagerV3.pluginIdentifier:
            guard let cgmManager = cgmManager as? LibreTransmitterManagerV3,
                  let batteryLevel = cgmManager.batteryLevel else { return nil }
            return GlucoseSourceInfo(description: nil, transmitterBattery: batteryLevel)

        case AppGroupCGM.pluginIdentifier:
            var description = "Group ID: \(Bundle.main.appGroupSuiteName ?? "Not set")"
            if let cgmManager = cgmManager as? AppGroupCGM,
               let app = cgmManager.appGroupSource.latestReadingFrom?.displayName ?? cgmManager.appGroupSource
               .latestReadingFromOther
            {
                description = "\(description), app: \(app)"
            }
            return GlucoseSourceInfo(description: description, transmitterBattery: nil)

        default: return nil
        }
    }
}

struct GlucoseSourceInfo {
    let description: String?
    let transmitterBattery: Double?
}
