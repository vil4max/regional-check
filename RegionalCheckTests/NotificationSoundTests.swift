import AVFoundation
import Foundation
import Testing

/// ALERT-push AC-12: the server names `drivecheck.caf` as the sound of every push, and iOS plays
/// it only when the app bundle holds it (a missing file falls back to the default sound).
struct NotificationSoundTests {
    @Test("ALERT-push AC-12 drivecheck.caf is in the app bundle, IMA4 in CAF and under one second")
    func soundIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "drivecheck", withExtension: "caf"))
        let file = try AVAudioFile(forReading: url)
        let seconds = Double(file.length) / file.fileFormat.sampleRate

        #expect(file.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatAppleIMA4)
        #expect(seconds > 0.3 && seconds < 1.0)
    }
}
