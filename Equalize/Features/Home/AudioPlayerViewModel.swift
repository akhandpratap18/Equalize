import Foundation
import AVFoundation

@Observable
final class AudioPlayerViewModel: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var isPlaying = false
    var progress: Double = 0.0
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    private var timer: Timer?

    func loadAudio(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("AudioPlayer error: \(error.localizedDescription)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = max(0, min(time, duration))
        self.currentTime = player.currentTime
        if self.duration > 0 {
            self.progress = self.currentTime / self.duration
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 1.0
        currentTime = duration
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            if self.duration > 0 {
                self.progress = self.currentTime / self.duration
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
