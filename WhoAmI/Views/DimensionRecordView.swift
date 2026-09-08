import SwiftUI

struct DimensionRecordView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechRecorder()
    @FocusState private var writing: Bool
    @State private var speechDomain: LifeDomain?
    @State private var speechBaseText = ""
    @State private var savedDomain: LifeDomain?
    @State private var saving = false
    @State private var finishingVoice = false
    @State private var startingVoice = false
    @State private var editorGenerations: [LifeDomain: UUID] = [:]

    private var domain: LifeDomain { store.recordingDomain }
    private var draft: DimensionDraft { store.dimensionDraft(for: domain) }
    private var hasBody: Bool { !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canSave: Bool { hasBody && draft.hasChosenIntensity }

    var body: some View {
        GeometryReader { geometry in
            let editingDomain = domain
            let generation = editorGenerations[editingDomain]
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 16) {
                        TimelineView(.periodic(from: .now, by: 1)) { clock in
                            let todayLevels = store.savedDimensionLevels(on: clock.date)
                            VStack(spacing: 8) {
                                HStack {
                                    Text(DateText.format(clock.date, "MM.dd · HH:mm:ss"))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .accessibilityIdentifier("record-clock")
                                    Spacer()
                                    if savedDomain == domain && todayLevels[domain] != nil {
                                        Label("已保存 · 新一条", systemImage: "checkmark")
                                            .accessibilityIdentifier("record-saved")
                                    } else {
                                        Text("滑动轮盘，选择维度")
                                    }
                                }
                                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                DimensionWheel(selection: $store.recordingDomain, savedLevels: todayLevels,
                                               diameter: min(300, max(254, geometry.size.height * 0.39)))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .id("wheel-top")

                        content

                        MoodEnergyControl(value: Binding(get: { store.dimensionDraft(for: editingDomain).intensity }, set: { value in
                            guard editorGenerations[editingDomain] == generation else { return }
                            updateDraft(for: editingDomain) { $0.intensity = value }
                        }), isCommitted: Binding(get: { store.dimensionDraft(for: editingDomain).hasChosenIntensity }, set: { committed in
                            guard editorGenerations[editingDomain] == generation else { return }
                            updateDraft(for: editingDomain) { $0.hasChosenIntensity = committed }
                        }))

                        Button {
                            writing = false
                            saving = true
                            let savingDomain = domain
                            Task { @MainActor in
                                await finishSpeech()
                                if store.saveDimension(savingDomain) != nil {
                                    editorGenerations[savingDomain] = UUID()
                                    savedDomain = savingDomain
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    withAnimation(.easeInOut(duration: 0.35)) { scroll.scrollTo("wheel-top", anchor: .top) }
                                }
                                saving = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if saving { ProgressView().tint(.white) }
                                Text(saving ? "保存中" : (hasBody && !draft.hasChosenIntensity ? "选择心境后保存" : "保存"))
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(Palette.accent.opacity(canSave ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain).disabled(!canSave || saving || finishingVoice || startingVoice)
                        .accessibilityIdentifier("record-save")
                    }
                    .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 26)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.recordingDomain) { _, _ in
                    writing = false
                    Task { await finishSpeech() }
                    savedDomain = nil
                }
            }
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if writing {
                HStack {
                    Spacer()
                    Button("完成") { writing = false }
                        .font(.system(size: 15, weight: .medium))
                        .frame(minWidth: 60, minHeight: 44)
                        .accessibilityIdentifier("record-keyboard-done")
                }
                .padding(.horizontal, 16)
                .background(Palette.background)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 0.5) }
            }
        }
        .accessibilityIdentifier("record-view")
        .onChange(of: speech.transcript) { _, text in applyTranscript(text) }
        .onChange(of: speech.isRecording) { wasRecording, isRecording in
            if wasRecording && !isRecording && !finishingVoice { Task { await finishSpeech() } }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { Task { await finishSpeech() } } }
        .onDisappear { Task { await finishSpeech() } }
    }

    private var content: some View {
        let editingDomain = domain
        let generation = editorGenerations[editingDomain]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(domain.title)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .id(domain)
                    .transition(.opacity)
                    .accessibilityIdentifier("record-domain-title")
                Spacer(minLength: 12)
                Button {
                    writing = false
                    if speech.isRecording {
                        Task { await finishSpeech() }
                    } else {
                        speechDomain = domain
                        speechBaseText = draft.body
                        startingVoice = true
                        Task {
                            await speech.start()
                            startingVoice = false
                        }
                    }
                } label: {
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(speech.isRecording ? Palette.line : Palette.surface,
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(saving || finishingVoice || startingVoice)
                .accessibilityLabel(speech.isRecording ? "结束语音" : "语音输入")
                .accessibilityIdentifier("record-voice")
            }
            Text(domain.prompt)
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .lineSpacing(3).accessibilityIdentifier("record-guidance")

            ZStack(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("从一件具体的事开始。")
                        .font(.system(size: 16)).foregroundStyle(Palette.secondary)
                        .padding(.top, 10).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(get: { store.dimensionDraft(for: editingDomain).body }, set: { text in
                    guard editorGenerations[editingDomain] == generation else { return }
                    updateDraft(for: editingDomain) { $0.body = text }
                }))
                .font(.system(size: 16)).lineSpacing(6)
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(height: writing ? 156 : 100)
                .focused($writing)
                .disabled(speech.isRecording || saving || finishingVoice || startingVoice)
                .id("\(editingDomain.rawValue):\(generation?.uuidString ?? "initial")")
                .accessibilityLabel("记录内容")
                .accessibilityIdentifier("record-body")
            }
            .padding(10)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 0.5))

            if speech.isRecording {
                HStack(spacing: 8) {
                    Circle().fill(Palette.ink).frame(width: 5, height: 5)
                    Text(speech.statusMessage ?? "正在转写 · 轻点方块结束")
                    Spacer()
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(0..<5) { index in
                            Capsule().fill(Palette.ink).frame(width: 2,
                                height: 4 + CGFloat(speech.meter) * CGFloat([8, 15, 22, 13, 7][index]))
                        }
                    }.frame(width: 24, height: 24).accessibilityHidden(true)
                }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            } else if let status = speech.statusMessage {
                Text(status).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("speech-status")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: domain)
    }

    private func finishSpeech() async {
        guard speechDomain != nil, !finishingVoice else { return }
        finishingVoice = true
        await speech.finish()
        applyTranscript(speech.transcript)
        speechDomain = nil
        finishingVoice = false
    }

    private func updateDraft(for target: LifeDomain, _ change: (inout DimensionDraft) -> Void) {
        var next = store.dimensionDraft(for: target)
        change(&next)
        store.setDimensionDraft(next, for: target)
        if target == domain { savedDomain = nil }
    }

    private func applyTranscript(_ text: String) {
        guard let target = speechDomain, !text.isEmpty else { return }
        var next = store.dimensionDraft(for: target)
        next.body = speechBaseText.isEmpty ? text : speechBaseText + "\n" + text
        store.setDimensionDraft(next, for: target)
        if target == domain { savedDomain = nil }
    }
}
