import AVFoundation

final class NavigationAlertSound: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(_ soundName: String) throws {
        guard soundName == (soundName as NSString).lastPathComponent,
              let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
            throw NSError(domain: "NavigationAlertSound", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled alert sound not found"])
        }
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        let next = try AVAudioPlayer(contentsOf: url)
        next.delegate = self
        player = next
        next.prepareToPlay()
        next.play()
    }

    func stop() { player?.stop(); player = nil }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { self.player = nil }
}
