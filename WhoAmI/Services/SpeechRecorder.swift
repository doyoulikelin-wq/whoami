import Foundation
import Combine
@preconcurrency import AVFoundation
@preconcurrency import Speech
import UIKit

/// Chinese dictation starts only when `start()` is explicitly invoked.
/// The app must supply NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription.
@MainActor
final class SpeechRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var meter: Double = 0

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionID = UUID()
    private var isStarting = false
    private var tapInstalled = false
    private var audioSessionActive = false
    private var finishTimeout: Task<Void, Never>?
    private var finishWaiters: [CheckedContinuation<Void, Never>] = []
    private var stopReason: String?
    private var subscriptions = Set<AnyCancellable>()

    func start() async {
        guard !isStarting else { return }
        // A new request must never receive an earlier request's queued results.
        invalidateAndCleanUp()
        let sessionID = UUID()
        recognitionID = sessionID
        isStarting = true
        transcript = ""
        statusMessage = nil
        observeInterruptions(for: sessionID)

        let authorization = await speechAuthorization()
        guard recognitionID == sessionID else { return }
        guard !Task.isCancelled else {
            completeSession(sessionID, message: "语音输入已取消。")
            return
        }
        switch authorization {
        case .authorized:
            break
        case .denied:
            completeSession(sessionID, message: "语音识别权限未开启。可在系统设置中修改，或继续输入文字。")
            return
        case .restricted:
            completeSession(sessionID, message: "系统限制了语音识别。可继续使用文字输入。")
            return
        case .notDetermined:
            completeSession(sessionID, message: "尚未获得语音识别权限。可继续使用文字输入。")
            return
        @unknown default:
            completeSession(sessionID, message: "当前语音识别授权状态不可用。可继续使用文字输入。")
            return
        }

        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard recognitionID == sessionID else { return }
        guard !Task.isCancelled else {
            completeSession(sessionID, message: "语音输入已取消。")
            return
        }
        guard microphoneAllowed else {
            completeSession(sessionID, message: "麦克风权限未开启。可在系统设置中修改，或继续输入文字。")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) else {
            completeSession(sessionID, message: "当前系统不支持中文语音识别。可继续使用文字输入。")
            return
        }
        guard recognizer.isAvailable else {
            completeSession(sessionID, message: "语音识别当前不可用。可稍后重试，或继续输入文字。")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            audioSessionActive = true
            guard session.isInputAvailable else {
                completeSession(sessionID, message: "当前没有可用的音频输入。可继续使用文字输入。")
                return
            }

            let engine = AVAudioEngine()
            audioEngine = engine
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                completeSession(sessionID, message: "音频输入格式不可用。请重新尝试，或继续输入文字。")
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            request.addsPunctuation = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            recognitionRequest = request
            self.recognizer = recognizer

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, request] buffer, _ in
                request.append(buffer)
                let level = Self.inputLevel(buffer)
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == sessionID, self.isRecording else { return }
                    self.meter = max(level, self.meter * 0.7)
                }
            }
            tapInstalled = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                // Copy the values before crossing back to the UI actor.
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor [weak self] in
                    self?.receive(text: text, isFinal: isFinal, failed: failed, sessionID: sessionID)
                }
            }
            engine.prepare()
            try engine.start()
            isStarting = false
            isRecording = true
            statusMessage = request.requiresOnDeviceRecognition
                ? "正在录音，使用设备端语音识别。"
                : "正在录音，使用系统语音识别；此设备可能连接 Apple 服务。"
        } catch {
            completeSession(sessionID, message: "音频输入启动失败。请重新尝试，或继续输入文字。")
        }
    }

    /// Stops microphone capture immediately and allows a brief final result to arrive.
    /// The already recognized transcript is retained, including on errors or interruptions.
    func stop() {
        if isStarting {
            completeSession(recognitionID, message: "语音输入已取消。")
            return
        }
        guard isRecording else { return }
        beginFinishing(reason: nil)
    }

    /// Use before saving or changing a recording target. Returns after the final result or
    /// a one-second timeout; no callback from this recording can mutate transcript afterward.
    func finish() async {
        stop()
        guard recognitionTask != nil else { return }
        await withCheckedContinuation { continuation in
            finishWaiters.append(continuation)
        }
    }

    private func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authorization in
                continuation.resume(returning: authorization)
            }
        }
    }

    private func receive(text: String?, isFinal: Bool, failed: Bool, sessionID: UUID) {
        guard recognitionID == sessionID else { return }
        // A final empty result or an error must not erase a useful partial result.
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            transcript = text
        }
        if isFinal {
            let message = stopReason ?? (transcript.isEmpty ? "未识别到有效语音。可重新录音或直接输入。" : "转写已完成。")
            completeSession(sessionID, message: message)
        } else if failed {
            let message = stopReason ?? (transcript.isEmpty
                ? "语音识别未返回文字。可重新尝试，或继续使用文字输入。"
                : "语音识别已结束，已识别文字保留。可继续编辑。")
            completeSession(sessionID, message: message)
        }
    }

    private func beginFinishing(reason: String?) {
        let sessionID = recognitionID
        stopReason = reason
        isRecording = false
        meter = 0
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        statusMessage = reason ?? "录音已停止，正在完成转写。"
        guard recognitionTask != nil else {
            completeSession(sessionID, message: reason ?? "录音已停止。")
            return
        }

        finishTimeout?.cancel()
        finishTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, self.recognitionID == sessionID else { return }
            let message = self.stopReason ?? (self.transcript.isEmpty
                ? "未识别到有效语音。可重新录音或直接输入。"
                : "录音已结束，已识别文字保留。")
            self.completeSession(sessionID, message: message)
        }
    }

    private func completeSession(_ sessionID: UUID, message: String) {
        guard recognitionID == sessionID else { return }
        invalidateAndCleanUp()
        statusMessage = message
    }

    private func invalidateAndCleanUp() {
        recognitionID = UUID()
        isStarting = false
        isRecording = false
        meter = 0
        finishTimeout?.cancel()
        finishTimeout = nil
        subscriptions.removeAll()
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        stopReason = nil
        let waiting = finishWaiters
        finishWaiters.removeAll()
        waiting.forEach { $0.resume() }
    }

    private func stopAudioInput() {
        audioEngine?.stop()
        if tapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine = nil
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
    }

    private func observeInterruptions(for sessionID: UUID) {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                Task { @MainActor [weak self] in
                    self?.interrupt(sessionID, message: "录音被系统中断。已识别文字保留，可继续输入。")
                }
            }.store(in: &subscriptions)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
                Task { @MainActor [weak self] in
                    self?.interrupt(sessionID, message: "音频输入设备已断开。已识别文字保留，可继续输入。")
                }
            }.store(in: &subscriptions)

        // Permission dialogs make the scene inactive; they must not cancel permission requests.
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.interrupt(sessionID, message: "应用已进入后台，录音停止。已识别文字保留。")
                }
            }.store(in: &subscriptions)
    }

    private func interrupt(_ sessionID: UUID, message: String) {
        guard recognitionID == sessionID else { return }
        if isStarting {
            completeSession(sessionID, message: message)
        } else if isRecording {
            beginFinishing(reason: message)
        }
    }

    nonisolated private static func inputLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?.pointee, buffer.frameLength > 0 else { return 0 }
        var squareSum = 0.0
        for index in 0..<Int(buffer.frameLength) {
            let sample = Double(samples[index])
            squareSum += sample * sample
        }
        let rms = sqrt(squareSum / Double(buffer.frameLength))
        guard rms.isFinite, rms > 0 else { return 0 }
        return min(max((20 * log10(rms) + 55) / 55, 0), 1)
    }

    deinit {
        finishTimeout?.cancel()
        recognitionTask?.cancel()
        audioEngine?.stop()
        if tapInstalled { audioEngine?.inputNode.removeTap(onBus: 0) }
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        finishWaiters.forEach { $0.resume() }
    }
}
