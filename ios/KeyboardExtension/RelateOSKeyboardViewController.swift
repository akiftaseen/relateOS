// RelateOSKeyboardViewController.swift
// RelateOS — iOS 26 Liquid Glass Keyboard Extension
// UIInputViewController subclass with full Cantonese/English support

import UIKit
import Combine

// MARK: - Main Keyboard View Controller

@available(iOSApplicationExtension 18.0, *)
final class RelateOSKeyboardViewController: UIInputViewController {

    // MARK: - Properties

    private var keyboardView: RelateOSKeyboardView!
    private var suggestionBar: SuggestionBarView!
    private var subtextTooltip: SubtextTooltipView!
    private var thinkingIndicator: ThinkingIndicatorView!

    private let aiEngine = KeyboardAIEngine()
    private let healthScoreProcessor = HealthScoreProcessor()
    private let captureManager = MessageCaptureManager()
    private var cancellables = Set<AnyCancellable>()

    private var currentDraft: String = ""
    private var analysisTask: Task<Void, Never>?
    private let startupSuggestions: [SuggestionModel] = [
        SuggestionModel(text: "我明白", tone: .empathetic, confidence: 0.84, id: "startup-1"),
        SuggestionModel(text: "慢慢講", tone: .gentle, confidence: 0.81, id: "startup-2"),
        SuggestionModel(text: "直接講", tone: .direct, confidence: 0.79, id: "startup-3")
    ]

    // AppGroup for sharing with main app
    private let sharedDefaults = UserDefaults(
        suiteName: "group.com.relateos.keyboard"
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSuggestionBar()
        setupKeyboardView()
        setupSubtextTooltip()
        setupThinkingIndicator()
        bindAIEngine()
        configureAppearance()
        showStartupState()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateLayout()
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        captureCurrentContext()
    }

    // MARK: - Setup

    private func setupKeyboardView() {
        keyboardView = RelateOSKeyboardView(
            inputViewController: self,
            delegate: self
        )
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor, constant: 0)
        ])
    }

    private func setupSuggestionBar() {
        suggestionBar = SuggestionBarView()
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionBar.delegate = self
        view.addSubview(suggestionBar)

        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    private func setupSubtextTooltip() {
        subtextTooltip = SubtextTooltipView()
        subtextTooltip.translatesAutoresizingMaskIntoConstraints = false
        subtextTooltip.alpha = 0
        view.addSubview(subtextTooltip)

        NSLayoutConstraint.activate([
            subtextTooltip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            subtextTooltip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            subtextTooltip.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor, constant: 4)
        ])
    }

    private func setupThinkingIndicator() {
        thinkingIndicator = ThinkingIndicatorView()
        thinkingIndicator.translatesAutoresizingMaskIntoConstraints = false
        thinkingIndicator.alpha = 0
        view.addSubview(thinkingIndicator)

        NSLayoutConstraint.activate([
            thinkingIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            thinkingIndicator.centerYAnchor.constraint(equalTo: suggestionBar.centerYAnchor)
        ])
    }

    private func configureAppearance() {
        view.backgroundColor = .clear
        // iOS 26 Liquid Glass effect
        if #available(iOSApplicationExtension 26.0, *) {
            view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.001)
        }
    }

    private func showStartupState() {
        suggestionBar.updateSuggestions(startupSuggestions)
        subtextTooltip.configure(
            explanation: "先用建議回覆，系統會再按對話內容調整語氣。",
            emotion: "中性",
            healthDelta: nil
        )
        subtextTooltip.alpha = 0
    }

    private func updateLayout() {
        let isLandscape = view.bounds.width > view.bounds.height
        keyboardView.updateForOrientation(isLandscape: isLandscape)
    }

    // MARK: - Context Capture

    private func captureCurrentContext() {
        let proxy = textDocumentProxy

        // Capture context from text document proxy (last 20 messages via AppGroup)
        let beforeText = proxy.documentContextBeforeInput ?? ""
        let afterText = proxy.documentContextAfterInput ?? ""
        let selectedText = proxy.selectedText ?? ""

        currentDraft = beforeText

        // Read shared message history from AppGroup
        let messageHistory = captureManager.readMessageHistory()

        // Trigger AI analysis with debounce
        scheduleAnalysis(
            draft: currentDraft,
            context: messageHistory,
            surrounding: (before: beforeText, after: afterText, selected: selectedText)
        )
    }

    private func scheduleAnalysis(
        draft: String,
        context: [Message],
        surrounding: (before: String, after: String, selected: String)
    ) {
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            // 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            await self?.runAnalysis(draft: draft, context: context)
        }
    }

    private func runAnalysis(draft: String, context: [Message]) async {
        guard !draft.isEmpty || !context.isEmpty else { return }

        await MainActor.run { [weak self] in
            self?.showThinkingState()
        }

        // Start 800ms timer — if no response, show "Thinking..." fallback
        let thinkingTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !Task.isCancelled {
                await MainActor.run { [weak self] in
                    self?.suggestionBar.showThinkingFallback()
                }
            }
        }

        do {
            await healthScoreProcessor.append(text: draft)
            let localHealthDelta = await healthScoreProcessor.latestDelta()

            let result = try await aiEngine.analyze(
                draft: draft,
                context: context
            )
            thinkingTask.cancel()

            await MainActor.run { [weak self] in
                self?.handleAnalysisResult(result, localHealthDelta: localHealthDelta)
            }
        } catch {
            thinkingTask.cancel()
            await MainActor.run { [weak self] in
                self?.hideThinkingState()
                self?.suggestionBar.updateSuggestions(self?.startupSuggestions ?? [])
                let fallbackDelta = self?.localizedFallbackHealthDelta(for: draft) ?? 0
                self?.sharedDefaults?.set(fallbackDelta, forKey: "latest_health_delta")
                self?.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "latest_health_delta_timestamp")
                self?.captureManager.appendHealthSample(delta: fallbackDelta)
                self?.publishHealthTrendSummary()
            }
        }
    }

    private func handleAnalysisResult(_ result: AIAnalysisResult, localHealthDelta: Float) {
        hideThinkingState()
        suggestionBar.updateSuggestions(result.suggestions)

        if let subtext = result.subtextExplanation, !subtext.isEmpty {
            subtextTooltip.configure(
                explanation: subtext,
                emotion: result.detectedEmotion,
                healthDelta: result.healthDelta
            )
            suggestionBar.showSubtextIndicator()
        }

        // Write health delta to AppGroup for main app
        let resolvedDelta = result.healthDelta ?? localHealthDelta
        sharedDefaults?.set(resolvedDelta, forKey: "latest_health_delta")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "latest_health_delta_timestamp")
        captureManager.appendHealthSample(delta: resolvedDelta)
        publishHealthTrendSummary()
    }

    private func localizedFallbackHealthDelta(for text: String) -> Float {
        let lowered = text.lowercased()
        if lowered.contains("sorry") || lowered.contains("明白") || lowered.contains("多謝") {
            return 0.12
        }
        if lowered.contains("whatever") || lowered.contains("算啦") || lowered.contains("你錯") {
            return -0.16
        }
        return 0
    }

    private func publishHealthTrendSummary() {
        let summary = captureManager.sevenDayTrendSummary()
        sharedDefaults?.set(summary.average, forKey: "health_delta_7d_average")
        sharedDefaults?.set(summary.latest, forKey: "health_delta_7d_latest")
        sharedDefaults?.set(summary.count, forKey: "health_delta_7d_count")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "health_delta_7d_timestamp")
    }

    private func showThinkingState() {
        UIView.animate(withDuration: 0.2) {
            self.thinkingIndicator.alpha = 1
        }
        thinkingIndicator.startAnimating()
    }

    private func hideThinkingState() {
        thinkingIndicator.stopAnimating()
        UIView.animate(withDuration: 0.2) {
            self.thinkingIndicator.alpha = 0
        }
    }

    // MARK: - AI Engine Binding

    private func bindAIEngine() {
        // Nothing to bind at init — reactive via async/await
    }
}

// MARK: - KeyboardViewDelegate

@available(iOSApplicationExtension 18.0, *)
extension RelateOSKeyboardViewController: KeyboardViewDelegate {

    func keyboardView(_ view: RelateOSKeyboardView, didTapKey key: KeyModel) {
        let proxy = textDocumentProxy

        switch key.type {
        case .character(let char):
            proxy.insertText(char)
            HapticEngine.shared.keyTap()
            view.consumeSingleShiftIfNeeded()

        case .space:
            proxy.insertText(" ")
            HapticEngine.shared.keyTap()

        case .delete:
            proxy.deleteBackward()
            HapticEngine.shared.deleteBackward()

        case .return:
            proxy.insertText("\n")
            HapticEngine.shared.keyTap()

        case .nextKeyboard:
            advanceToNextInputMode()

        case .dismissKeyboard:
            dismissKeyboard()

        case .shift:
            view.toggleShift()

        case .switchToNumeric:
            view.switchToNumericMode()

        case .switchToAlpha:
            view.switchToAlphaMode()

        case .emoji:
            view.switchToEmojiMode()
        }
    }

    func keyboardViewDidTapGlobe(_ view: RelateOSKeyboardView) {
        advanceToNextInputMode()
    }
}

// MARK: - SuggestionBarDelegate

@available(iOSApplicationExtension 18.0, *)
extension RelateOSKeyboardViewController: SuggestionBarDelegate {

    func suggestionBar(_ bar: SuggestionBarView, didSelectSuggestion suggestion: SuggestionModel) {
        let proxy = textDocumentProxy
        
        // Insert suggestion at cursor; do not delete full pre-context from the host field.
        if let before = proxy.documentContextBeforeInput, !before.isEmpty, !before.hasSuffix(" ") {
            proxy.insertText(" ")
        }
        proxy.insertText(suggestion.text)
        HapticEngine.shared.suggestionAccepted()

        // Log selection for model improvement (stored locally)
        captureManager.logSuggestionSelected(
            suggestion: suggestion,
            context: currentDraft
        )

        hideSubtextTooltip()
    }

    func suggestionBarDidTapSubtextIndicator(_ bar: SuggestionBarView) {
        toggleSubtextTooltip()
    }

    private func toggleSubtextTooltip() {
        let isVisible = subtextTooltip.alpha > 0
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5
        ) {
            self.subtextTooltip.alpha = isVisible ? 0 : 1
            self.subtextTooltip.transform = isVisible
                ? CGAffineTransform(translationX: 0, y: -8)
                : .identity
        }
    }

    private func hideSubtextTooltip() {
        UIView.animate(withDuration: 0.2) {
            self.subtextTooltip.alpha = 0
        }
    }
}
