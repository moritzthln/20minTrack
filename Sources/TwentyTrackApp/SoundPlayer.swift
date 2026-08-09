import AppKit

/// Single soft chime at check-in boundaries — system "Glass", never a
/// sequence (this app nudges four times an hour; it must stay gentle).
enum SoundPlayer {
    private static var current: NSSound?

    static func playChime(volume: Double) {
        current?.stop()
        guard let sound = NSSound(named: "Glass") else { return }
        sound.volume = Float(min(1, max(0, volume)))
        current = sound
        sound.play()
    }
}
