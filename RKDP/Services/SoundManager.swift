import AudioToolbox
import UIKit

/// Plays system sounds and haptics for word-finding events.
/// Uses AudioToolbox only — no audio files required.
@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    // MARK: - Combo state

    private var lastWordTime: Date?
    private var comboCount = 0
    private let comboWindow: TimeInterval = 3.0

    // MARK: - Word found

    /// Call whenever a valid word is accepted. Length drives both haptic weight and sound pitch.
    func wordFound(length: Int) {
        // Haptic intensity scales with word length
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch length {
        case 3:    style = .light
        case 4:    style = .medium
        default:   style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()

        // System sound escalates with length
        //  1104 = SMS received (short click)
        //  1057 = Pinball (satisfying pop)
        //  1016 = New voicemail (brighter)
        //  1025 = Calendar alert (punchy)
        //  1394 = Ping (premium reward)
        let soundID: SystemSoundID
        switch length {
        case 3:    soundID = 1104
        case 4:    soundID = 1057
        case 5:    soundID = 1016
        case 6:    soundID = 1025
        default:   soundID = 1394
        }
        AudioServicesPlaySystemSound(soundID)

        // Combo detection
        let now = Date()
        if let last = lastWordTime, now.timeIntervalSince(last) < comboWindow {
            comboCount += 1
            if comboCount >= 2 { playCombo(count: comboCount) }
        } else {
            comboCount = 1
        }
        lastWordTime = now
    }

    // MARK: - Invalid / already found

    func wordInvalid() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        AudioServicesPlaySystemSound(1521)
    }

    // MARK: - Game over

    func gameOver() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025)
    }

    // MARK: - Combo

    private func playCombo(count: Int) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let reps = min(count, 4)
        for i in 0..<reps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                AudioServicesPlaySystemSound(1394)
            }
        }
    }

    func resetCombo() {
        comboCount = 0
        lastWordTime = nil
    }
}
