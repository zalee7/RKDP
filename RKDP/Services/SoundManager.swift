import AudioToolbox
import AVFoundation
import UIKit

/// Plays bundled audio, system sounds, and haptics for game events.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    enum AudioAsset: String, Hashable {
        case gameFound = "GameFound"
        case inOnlineGame = "InOnlineGame"
        case matchmaking = "Matchmaking"
        case otherKeyboardPress = "OtherKeyboardPress"
        case wordleTileClick = "WordleTileClick"
    }

    private var oneShotPlayers: [AudioAsset: AVAudioPlayer] = [:]
    private var loopPlayers: [AudioAsset: AVAudioPlayer] = [:]

    private init() {
        configureSession()
    }

    // MARK: - Bundled audio

    func playGameFound() {
        playOneShot(.gameFound, volume: 1.0)
    }

    func playMatchmakingLoop() {
        playLoop(.matchmaking, volume: 0.78)
    }

    func stopMatchmakingLoop() {
        stopLoop(.matchmaking)
    }

    func playOnlineGameLoop() {
        playLoop(.inOnlineGame, volume: 0.14)
    }

    func stopOnlineGameLoop() {
        stopLoop(.inOnlineGame)
    }

    func stopAllLoops() {
        stopMatchmakingLoop()
        stopOnlineGameLoop()
    }

    func keyboardPress() {
        playOneShot(.otherKeyboardPress, volume: 0.75)
    }

    func wordleTileClick() {
        playOneShot(.wordleTileClick, volume: 0.85)
    }

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

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func playOneShot(_ asset: AudioAsset, volume: Float) {
        guard let player = player(for: asset, looping: false) else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    private func playLoop(_ asset: AudioAsset, volume: Float) {
        guard let player = player(for: asset, looping: true) else { return }
        player.volume = volume
        if !player.isPlaying {
            player.currentTime = 0
            player.play()
        }
    }

    private func stopLoop(_ asset: AudioAsset) {
        guard let player = loopPlayers[asset] else { return }
        player.stop()
        player.currentTime = 0
    }

    private func player(for asset: AudioAsset, looping: Bool) -> AVAudioPlayer? {
        if looping, let player = loopPlayers[asset] { return player }
        if !looping, let player = oneShotPlayers[asset] { return player }

        do {
            let player: AVAudioPlayer
            if let data = NSDataAsset(name: asset.rawValue)?.data {
                player = try AVAudioPlayer(data: data)
            } else if let url = Bundle.main.url(forResource: asset.rawValue, withExtension: "mp3") {
                player = try AVAudioPlayer(contentsOf: url)
            } else {
                return nil
            }
            player.numberOfLoops = looping ? -1 : 0
            player.prepareToPlay()
            if looping {
                loopPlayers[asset] = player
            } else {
                oneShotPlayers[asset] = player
            }
            return player
        } catch {
            return nil
        }
    }
}
