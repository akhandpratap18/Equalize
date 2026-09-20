import Foundation
import AVFoundation
import Speech

@MainActor
@Observable
final class VoiceAssistantManager: NSObject, AVAudioRecorderDelegate {
    enum RecognizerError: LocalizedError {
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorizedToRecognize: return "Speech recognition isn't authorized."
            case .notPermittedToRecord: return "Microphone access isn't permitted."
            case .recognizerIsUnavailable: return "Speech recognizer is temporarily unavailable."
            }
        }
    }

    override init() {
        super.init()
    }

    var isPaused = false
    var recognizedText = ""
    var errorMessage: String?
    var audioLevel: Float = 0.0
    var recordingFileURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    
    var lastSegments: [SFTranscriptionSegment] = []

    func startListening() {
        Task {
            do {
                try await requestPermissions()
                try startRecording()
            } catch {
                Task { @MainActor in
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        isPaused = true
        audioRecorder?.stop()
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        guard speechStatus == .authorized else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }

        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        guard micGranted else {
            throw NSError(domain: "VoiceManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }
    }

    private func startRecording() throws {
        recognizedText = ""
        isPaused = false
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try audioSession.setActive(true)

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        // Run metering loop
        let recorder = audioRecorder
        Task {
            while !self.isPaused, let rec = recorder, rec.isRecording {
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                let normalized = max(0, power + 50) / 50.0
                self.audioLevel = Float(0.5 + (normalized * 2.5))
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }
    }
}
