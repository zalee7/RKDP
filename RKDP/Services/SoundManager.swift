import AudioToolbox
import AVFoundation
import UIKit

enum AppPreferenceKeys {
    static let soundEffectsEnabled = "settings.soundEffectsEnabled"
    static let musicEnabled = "settings.musicEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let reduceExtraAnimations = "settings.reduceExtraAnimations"
}

/// Plays bundled audio, system sounds, and haptics for game events.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    enum AudioAsset: String, Hashable {
        case gameFound = "GameFound"
        case gridLoss = "GridLoss"
        case gridVictory = "GridVictory"
        case inOnlineGame = "InOnlineGame"
        case matchmaking = "Matchmaking"
        case otherKeyboardPress = "OtherKeyboardPress"
        case wordCombo1 = "WordCombo1"
        case wordCombo2 = "WordCombo2"
        case wordCombo3 = "WordCombo3"
        case wordCombo4 = "WordCombo4"
        case wordCombo5 = "WordCombo5"
        case wordAlreadyUsed = "WordAlreadyUsed"
        case wordInvalid = "WordInvalid"
        case clearErase = "ClearErase"
        case erase = "Erase"
        case colorLinkAttached = "ColorLinkAttached"
        case appButtonTap = "AppButtonTap"
        case wordleTileClick = "WordleTileClick"
        case preGameCountdown = "PreGameCountdown"
        case placingCard = "PlacingCard"
        case puzzlePartyCardShuffle = "PuzzlePartyCardShuffle"
        case timeRunningOut = "TimeRunningOut"
    }

    private var oneShotPlayers: [AudioAsset: AVAudioPlayer] = [:]
    private var loopPlayers: [AudioAsset: AVAudioPlayer] = [:]
    private var timerUrgencyIsPlaying = false
    private var lastCountdownSessionID: String?

    private init() {
        configureSession()
    }

    // MARK: - Bundled audio

    func playGameFound() {
        playOneShot(.gameFound, volume: 1.0)
    }

    func playMatchVictory() {
        playOneShot(.gridVictory, volume: 1.0)
    }

    func playMatchLoss() {
        playOneShot(.gridLoss, volume: 1.0)
    }

    func playMatchmakingLoop() {
        guard musicEnabled else { return }
        playLoop(.matchmaking, volume: 0.78)
    }

    func stopMatchmakingLoop() {
        stopLoop(.matchmaking)
    }

    func playOnlineGameLoop() {
        guard musicEnabled else { return }
        playLoop(.inOnlineGame, volume: 0.14)
    }

    func stopOnlineGameLoop() {
        stopLoop(.inOnlineGame)
    }

    func stopAllLoops() {
        stopMatchmakingLoop()
        stopOnlineGameLoop()
        setTimerUrgency(false)
    }

    func playPreGameCountdown(sessionID: String) {
        guard lastCountdownSessionID != sessionID else { return }
        lastCountdownSessionID = sessionID
        playOneShot(.preGameCountdown, volume: 0.9)
    }

    func setTimerUrgency(_ active: Bool) {
        guard active, soundEffectsEnabled else {
            timerUrgencyIsPlaying = false
            stopLoop(.timeRunningOut)
            return
        }
        guard !timerUrgencyIsPlaying else { return }
        guard let player = player(for: .timeRunningOut, looping: true) else { return }
        player.volume = 0.45
        player.currentTime = 0
        player.play()
        timerUrgencyIsPlaying = true
    }

    func keyboardPress() {
        playOneShot(.otherKeyboardPress, volume: 0.75)
    }

    /// Reserved for intentional navigation and primary app actions, never per-key gameplay input.
    func appButtonTap() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        playOneShot(.appButtonTap, volume: 0.58)
    }

    func wordleTileClick() {
        playOneShot(.wordleTileClick, volume: 0.85)
    }

    /// A non-gameplay sample for cosmetic previews. Keep the cosmetic ID here so
    /// a future sound pack can replace these category defaults per theme.
    func playThemePreview(for item: CosmeticItem) {
        guard soundEffectsEnabled else { return }

        let soundID: SystemSoundID
        let haptic: UIImpactFeedbackGenerator.FeedbackStyle
        switch item.category {
        case .boardTheme:
            soundID = 1104
            haptic = .light
        case .tileTheme:
            soundID = 1057
            haptic = .medium
        case .cardTheme:
            soundID = 1110
            haptic = .light
        default:
            soundID = 1104
            haptic = .light
        }

        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: haptic).impactOccurred()
        }
        AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Word found

    /// Call whenever a valid word is accepted. Each authored combo cue maps to its word length.
    func wordFound(length: Int) {
        // Haptic intensity scales with word length
        if hapticsEnabled {
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch length {
            case 3:    style = .light
            case 4:    style = .medium
            default:   style = .heavy
            }
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        playWordLengthCue(length: length)
    }

    // MARK: - Invalid / already found

    func wordInvalid() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        playOneShot(.wordInvalid, volume: 0.85)
    }

    func wordAlreadyUsed() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        playOneShot(.wordAlreadyUsed, volume: 0.8)
    }

    func clearErase() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        playOneShot(.clearErase, volume: 0.75)
    }

    func erase() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        playOneShot(.erase, volume: 0.62)
    }

    func solitairePlaceCard() {
        playOneShot(.placingCard, volume: 0.78)
    }

    func solitaireShuffleCards() {
        playOneShot(.puzzlePartyCardShuffle, volume: 0.8)
    }

    func colorLinkAttached() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        playOneShot(.colorLinkAttached, volume: 0.9)
    }

    // MARK: - Game over

    func gameOver() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if soundEffectsEnabled {
            AudioServicesPlaySystemSound(1025)
        }
    }

    // MARK: - Word length cues

    private func playWordLengthCue(length: Int) {
        let asset: AudioAsset
        switch min(max(length - 2, 1), 5) {
        case 1: asset = .wordCombo1 // 3 letters
        case 2: asset = .wordCombo2 // 4 letters
        case 3: asset = .wordCombo3 // 5 letters
        case 4: asset = .wordCombo4 // 6 letters
        default: asset = .wordCombo5
        }
        playOneShot(asset, volume: 0.9)
    }

    /// Retained for existing game lifecycle call sites. Word cues no longer depend on a combo timer.
    func resetCombo() {
        // Intentionally empty.
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func playOneShot(_ asset: AudioAsset, volume: Float) {
        guard soundEffectsEnabled else { return }
        guard let player = player(for: asset, looping: false) else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    private func playLoop(_ asset: AudioAsset, volume: Float) {
        guard musicEnabled else { return }
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

    private var soundEffectsEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.soundEffectsEnabled) as? Bool ?? true
    }

    private var musicEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.musicEnabled) as? Bool ?? true
    }

    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.hapticsEnabled) as? Bool ?? true
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
