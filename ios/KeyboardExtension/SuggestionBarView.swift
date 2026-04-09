// SuggestionBarView.swift
// RelateOS — SwiftUI-hosted AI Suggestion Bar with system glass styles

import UIKit
import SwiftUI

// MARK: - Models

struct SuggestionModel {
    let text: String       // max 40 chars
    let tone: SuggestionTone
    let confidence: Float
    let id: String
}

enum SuggestionTone: String {
    case gentle     = "gentle"
    case direct     = "direct"
    case humorous   = "humorous"
    case empathetic = "empathetic"
    case assertive  = "assertive"
    case deflect    = "deflect"

    var color: UIColor {
        switch self {
        case .gentle:     return UIColor(red: 0.45, green: 0.78, blue: 0.65, alpha: 1)
        case .direct:     return UIColor(red: 0.35, green: 0.60, blue: 0.95, alpha: 1)
        case .humorous:   return UIColor(red: 0.95, green: 0.72, blue: 0.28, alpha: 1)
        case .empathetic: return UIColor(red: 0.85, green: 0.50, blue: 0.80, alpha: 1)
        case .assertive:  return UIColor(red: 0.95, green: 0.42, blue: 0.38, alpha: 1)
        case .deflect:    return UIColor(red: 0.65, green: 0.65, blue: 0.70, alpha: 1)
        }
    }

    var icon: String {
        switch self {
        case .gentle:     return "leaf.fill"
        case .direct:     return "arrow.right.circle.fill"
        case .humorous:   return "face.smiling.fill"
        case .empathetic: return "heart.fill"
        case .assertive:  return "bolt.fill"
        case .deflect:    return "wind"
        }
    }

    var label: String {
        switch self {
        case .gentle:     return "溫和"
        case .direct:     return "直接"
        case .humorous:   return "幽默"
        case .empathetic: return "同理"
        case .assertive:  return "堅定"
        case .deflect:    return "迴避"
        }
    }
}

// MARK: - Delegate

@MainActor
@available(iOSApplicationExtension 18.0, *)
protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelectSuggestion suggestion: SuggestionModel)
    func suggestionBarDidTapSubtextIndicator(_ bar: SuggestionBarView)
    func suggestionBarDidTapAnalyze(_ bar: SuggestionBarView)
}

// MARK: - Suggestion Bar (UIKit host)

@available(iOSApplicationExtension 18.0, *)
final class SuggestionBarView: UIView {

    weak var delegate: SuggestionBarDelegate?

    private let state = SuggestionBarState()
    private var hostingController: UIHostingController<SuggestionBarRootView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        let root = SuggestionBarRootView(
            state: state,
            onSuggestionTap: { [weak self] suggestion in
                guard let self else { return }
                delegate?.suggestionBar(self, didSelectSuggestion: suggestion)
            },
            onSubtextTap: { [weak self] in
                guard let self else { return }
                delegate?.suggestionBarDidTapSubtextIndicator(self)
            },
            onAnalyzeTap: { [weak self] in
                guard let self else { return }
                delegate?.suggestionBarDidTapAnalyze(self)
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = host

        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func updateSuggestions(_ suggestions: [SuggestionModel]) {
        state.updateSuggestions(suggestions)
    }

    func showThinkingFallback() {
        state.showThinkingFallback()
    }

    func showSubtextIndicator() {
        state.showSubtextIndicator()
    }

    func setManualAnalyzeEnabled(_ enabled: Bool) {
        state.setManualAnalyzeEnabled(enabled)
    }
}

// MARK: - SwiftUI State

@available(iOSApplicationExtension 18.0, *)
private final class SuggestionBarState: ObservableObject {
    @Published var suggestions: [SuggestionModel] = []
    @Published var isThinking = false
    @Published var showSubtextButton = false
    @Published var showAnalyzeButton = false

    func updateSuggestions(_ newSuggestions: [SuggestionModel]) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            suggestions = Array(newSuggestions.prefix(3))
            isThinking = false
        }
    }

    func showThinkingFallback() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isThinking = true
        }
    }

    func showSubtextIndicator() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.25)) {
            showSubtextButton = true
        }
    }

    func setManualAnalyzeEnabled(_ enabled: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showAnalyzeButton = enabled
        }
    }
}

// MARK: - SwiftUI Views

@available(iOSApplicationExtension 18.0, *)
private struct SuggestionBarRootView: View {
    @ObservedObject var state: SuggestionBarState
    let onSuggestionTap: (SuggestionModel) -> Void
    let onSubtextTap: () -> Void
    let onAnalyzeTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            headerStrip
            contentRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(UIColor.secondarySystemBackground).opacity(0.9),
                            Color(UIColor.tertiarySystemBackground).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var headerStrip: some View {
        HStack(spacing: 8) {
            Label("AI suggestions", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(UIColor.label))

            Spacer()

            Text(state.isThinking ? "Thinking" : "Ready")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(state.isThinking ? Color.orange : Color.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (state.isThinking ? Color.orange : Color.green)
                        .opacity(0.16)
                )
                .clipShape(Capsule())

            confidenceBadge
        }
    }

    @ViewBuilder
    private var confidenceBadge: some View {
        if let topSuggestion = state.suggestions.first {
            Text("\(Int(topSuggestion.confidence * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(topSuggestion.tone.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(topSuggestion.tone.color).opacity(0.14))
                .clipShape(Capsule())
        }
    }

    private var contentRow: some View {
        HStack(spacing: 10) {
            actionRail

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(state.suggestions, id: \.id) { suggestion in
                        SuggestionBubbleView(suggestion: suggestion) {
                            onSuggestionTap(suggestion)
                        }
                        .opacity(state.isThinking ? 0.55 : 1.0)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 52)

            if state.isThinking {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 2)
            }
        }
    }

    @ViewBuilder
    private var actionRail: some View {
        if state.showAnalyzeButton || state.showSubtextButton {
            HStack(spacing: 8) {
                if state.showAnalyzeButton {
                    Button(action: onAnalyzeTap) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(AssistantBubbleButtonStyle(cornerRadius: 12))
                    .accessibilityLabel("Analyze current text")
                    .transition(.scale.combined(with: .opacity))
                }

                if state.showSubtextButton {
                    Button(action: onSubtextTap) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(AssistantBubbleButtonStyle(cornerRadius: 12))
                    .accessibilityLabel("Subtext explanation")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: state.showAnalyzeButton && state.showSubtextButton ? 96 : 48)
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct SuggestionBubbleView: View {
    let suggestion: SuggestionModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: suggestion.tone.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(suggestion.tone.color))
                    Text(suggestion.tone.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(suggestion.tone.color))
                    Spacer(minLength: 6)
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }

                Text(suggestion.text)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(UIColor.label))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 158, maxWidth: 200, minHeight: 52, maxHeight: 52, alignment: .leading)
        }
        .buttonStyle(AssistantBubbleButtonStyle(cornerRadius: 12))
        .accessibilityLabel(suggestion.text)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct AssistantBubbleButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground).opacity(0.98),
                        Color(UIColor.secondarySystemBackground).opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Auxiliary UIKit Views

@available(iOSApplicationExtension 18.0, *)
final class SubtextTooltipView: UIView {

    private let explanationLabel = UILabel()
    private let metadataLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        if #available(iOSApplicationExtension 26.0, *) {
            backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.42)
        } else {
            backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.78)
        }

        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor

        explanationLabel.numberOfLines = 0
        explanationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        explanationLabel.textColor = .label

        metadataLabel.numberOfLines = 1
        metadataLabel.font = .systemFont(ofSize: 11, weight: .regular)
        metadataLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [explanationLabel, metadataLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    func configure(explanation: String, emotion: String?, healthDelta: Float?) {
        explanationLabel.text = explanation

        let emotionText = (emotion?.isEmpty == false) ? emotion! : "未知"

        if let healthDelta {
            let sign = healthDelta >= 0 ? "+" : ""
            metadataLabel.text = "情緒: \(emotionText)  關係分數: \(sign)\(String(format: "%.1f", healthDelta))"
        } else {
            metadataLabel.text = "情緒: \(emotionText)"
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
final class ThinkingIndicatorView: UIView {

    private let indicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .secondaryLabel
        addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: trailingAnchor),
            indicator.topAnchor.constraint(equalTo: topAnchor),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func startAnimating() {
        indicator.startAnimating()
    }

    func stopAnimating() {
        indicator.stopAnimating()
    }
}
