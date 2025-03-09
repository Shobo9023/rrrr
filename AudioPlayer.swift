import AVFoundation

class AudioPlayer {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?

    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func currentTime() -> TimeInterval {
        return player?.currentTime ?? 0
    }

    func duration() -> TimeInterval {
        return player?.duration ?? 0
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
    }
}
