// SuggestionBarView.swift
// RelateOS — AI Suggestion Bar with Liquid Glass Bubbles

import UIKit

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

@available(iOSApplicationExtension 18.0, *)
protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelectSuggestion suggestion: SuggestionModel)
    func suggestionBarDidTapSubtextIndicator(_ bar: SuggestionBarView)
}

// MARK: - Suggestion Bar

@available(iOSApplicationExtension 18.0, *)
final class SuggestionBarView: UIView {

    weak var delegate: SuggestionBarDelegate?

    // MARK: - UI Components

    private var scrollView: UIScrollView!
    private var contentStack: UIStackView!
    private var subtextButton: SubtextIndicatorButton!
    private var thinkingLabel: UILabel!

    private var suggestionBubbles: [SuggestionBubble] = []
    private var currentSuggestions: [SuggestionModel] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        // Top separator line (ultra thin)
        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.33)
        ])

        // Glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Scroll view for suggestions
        scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 52)
        blur.contentView.addSubview(scrollView)

        contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -44),
            scrollView.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        // Subtext indicator button (right side)
        subtextButton = SubtextIndicatorButton()
        subtextButton.translatesAutoresizingMaskIntoConstraints = false
        subtextButton.alpha = 0
        subtextButton.addTarget(self, action: #selector(subtextTapped), for: .touchUpInside)
        blur.contentView.addSubview(subtextButton)

        NSLayoutConstraint.activate([
            subtextButton.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -8),
            subtextButton.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            subtextButton.widthAnchor.constraint(equalToConstant: 36),
            subtextButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Thinking label
        thinkingLabel = UILabel()
        thinkingLabel.text = "思考中…"
        thinkingLabel.font = .systemFont(ofSize: 13, weight: .regular)
        thinkingLabel.textColor = .secondaryLabel
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        thinkingLabel.alpha = 0
        blur.contentView.addSubview(thinkingLabel)
        NSLayoutConstraint.activate([
            thinkingLabel.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            thinkingLabel.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])
    }

    // MARK: - Public Interface

    func updateSuggestions(_ suggestions: [SuggestionModel]) {
        currentSuggestions = suggestions

        // Animate out old bubbles
        let oldBubbles = suggestionBubbles
        UIView.animate(withDuration: 0.15, animations: {
            oldBubbles.forEach {
                $0.alpha = 0
                $0.transform = CGAffineTransform(translationX: 0, y: 8)
            }
        }) { _ in
            oldBubbles.forEach { $0.removeFromSuperview() }
        }
        suggestionBubbles.removeAll()

        // Animate in new bubbles
        thinkingLabel.alpha = 0

        for (index, suggestion) in suggestions.prefix(3).enumerated() {
            let bubble = SuggestionBubble(suggestion: suggestion)
            bubble.alpha = 0
            bubble.transform = CGAffineTransform(translationX: 0, y: 12)
            bubble.addTarget(self, action: #selector(bubbleTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(bubble)
            suggestionBubbles.append(bubble)

            UIView.animate(
                withDuration: 0.3,
                delay: Double(index) * 0.06,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.5
            ) {
                bubble.alpha = 1
                bubble.transform = .identity
            }
        }

        // Scroll back to start
        scrollView.setContentOffset(CGPoint(x: -12, y: 0), animated: true)
    }

    func showThinkingFallback() {
        UIView.animate(withDuration: 0.2) {
            self.thinkingLabel.alpha = 1
            self.suggestionBubbles.forEach { $0.alpha = 0.3 }
        }
    }

    func showSubtextIndicator() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0.3,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0
        ) {
            self.subtextButton.alpha = 1
            self.subtextButton.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func bubbleTapped(_ bubble: SuggestionBubble) {
        bubble.animateSelection()
        delegate?.suggestionBar(self, didSelectSuggestion: bubble.suggestion)
    }

    @objc private func subtextTapped() {
        subtextButton.animatePulse()
        delegate?.suggestionBarDidTapSubtextIndicator(self)
    }
}

// MARK: - Suggestion Bubble

@available(iOSApplicationExtension 18.0, *)
final class SuggestionBubble: UIControl {

    let suggestion: SuggestionModel

    private let containerStack = UIStackView()
    private let toneIconView = UIImageView()
    private let textLabel = UILabel()
    private let tonePillView = TonePillView()

    private var glassBackground: UIVisualEffectView!

    init(suggestion: SuggestionModel) {
        self.suggestion = suggestion
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // Liquid glass bubble background
        glassBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        glassBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassBackground)
        NSLayoutConstraint.activate([
            glassBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackground.topAnchor.constraint(equalTo: topAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Tone color accent overlay
        let toneOverlay = UIView()
        toneOverlay.backgroundColor = suggestion.tone.color.withAlphaComponent(0.15)
        toneOverlay.translatesAutoresizingMaskIntoConstraints = false
        glassBackground.contentView.addSubview(toneOverlay)
        NSLayoutConstraint.activate([
            toneOverlay.leadingAnchor.constraint(equalTo: glassBackground.contentView.leadingAnchor),
            toneOverlay.trailingAnchor.constraint(equalTo: glassBackground.contentView.trailingAnchor),
            toneOverlay.topAnchor.constraint(equalTo: glassBackground.contentView.topAnchor),
            toneOverlay.bottomAnchor.constraint(equalTo: glassBackground.contentView.bottomAnchor)
        ])

        // Content
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 2
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        glassBackground.contentView.addSubview(contentStack)

        // Tone pill (top)
        tonePillView.configure(tone: suggestion.tone)
        contentStack.addArrangedSubview(tonePillView)

        // Suggestion text
        textLabel.text = suggestion.text
        textLabel.font = .systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.1, alpha: 1)
        }
        textLabel.numberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail
        contentStack.addArrangedSubview(textLabel)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: glassBackground.contentView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: glassBackground.contentView.trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: glassBackground.contentView.topAnchor, constant: 7),
            contentStack.bottomAnchor.constraint(equalTo: glassBackground.contentView.bottomAnchor, constant: -7)
        ])

        // Border accent
        layer.borderColor = suggestion.tone.color.withAlphaComponent(0.4).cgColor
        layer.borderWidth = 0.5

        // Shadow
        layer.shadowColor = suggestion.tone.color.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        layer.shadowOffset = .zero

        // Max width constraint
        widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
    }

    func animateSelection() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.alpha = 0.6
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0,
                           usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                self.transform = .identity
                self.alpha = 1.0
            }
        }

        // Ripple flash in tone color
        let flash = UIView(frame: bounds)
        flash.backgroundColor = suggestion.tone.color.withAlphaComponent(0.3)
        flash.layer.cornerRadius = layer.cornerRadius
        flash.layer.cornerCurve = .continuous
        addSubview(flash)
        UIView.animate(withDuration: 0.35) {
            flash.alpha = 0
        } completion: { _ in
            flash.removeFromSuperview()
        }
    }
}

// MARK: - Tone Pill View

@available(iOSApplicationExtension 18.0, *)
final class TonePillView: UIView {

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 3
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        label.font = .systemFont(ofSize: 10, weight: .semibold)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(tone: SuggestionTone) {
        iconView.image = UIImage(systemName: tone.icon)?
            .withRenderingMode(.alwaysTemplate)
        iconView.tintColor = tone.color
        label.text = tone.label
        label.textColor = tone.color
    }
}

// MARK: - Subtext Indicator Button

@available(iOSApplicationExtension 18.0, *)
final class SubtextIndicatorButton: UIButton {

    private let rippleLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.layer.cornerRadius = 18
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let icon = UIImageView(image: UIImage(systemName: "sparkles")?
            .withRenderingMode(.alwaysTemplate))
        icon.tintColor = UIColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isUserInteractionEnabled = false
        blur.contentView.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])

        layer.borderColor = UIColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.4).cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
    }

    func animatePulse() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.15
        pulse.duration = 0.15
        pulse.autoreverses = true
        layer.add(pulse, forKey: "pulse")
    }
}

// MARK: - Subtext Tooltip View

@available(iOSApplicationExtension 18.0, *)
final class SubtextTooltipView: UIView {

    private let containerBlur: UIVisualEffectView
    private let iconView = UIImageView()
    private let emotionLabel = UILabel()
    private let explanationLabel = UILabel()
    private let healthDeltaView = HealthDeltaBadge()

    override init(frame: CGRect) {
        containerBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        containerBlur.layer.cornerRadius = 14
        containerBlur.layer.cornerCurve = .continuous
        containerBlur.clipsToBounds = true
        containerBlur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerBlur)
        NSLayoutConstraint.activate([
            containerBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerBlur.topAnchor.constraint(equalTo: topAnchor),
            containerBlur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Header row
        let headerStack = UIStackView(arrangedSubviews: [iconView, emotionLabel, UIView(), healthDeltaView])
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center

        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.tintColor = UIColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)

        emotionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        emotionLabel.textColor = .secondaryLabel

        // Explanation text
        explanationLabel.font = .systemFont(ofSize: 13, weight: .regular)
        explanationLabel.textColor = .label
        explanationLabel.numberOfLines = 3
        explanationLabel.lineBreakMode = .byWordWrapping

        let mainStack = UIStackView(arrangedSubviews: [headerStack, explanationLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 6
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        containerBlur.contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: containerBlur.contentView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: containerBlur.contentView.trailingAnchor, constant: -14),
            mainStack.topAnchor.constraint(equalTo: containerBlur.contentView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: containerBlur.contentView.bottomAnchor, constant: -10)
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        layer.borderWidth = 0.5
    }

    func configure(explanation: String, emotion: String?, healthDelta: Float?) {
        explanationLabel.text = explanation

        if let emotion = emotion {
            emotionLabel.text = emotion
            iconView.image = UIImage(systemName: "waveform.path.ecg")?
                .withRenderingMode(.alwaysTemplate)
        }

        if let delta = healthDelta {
            healthDeltaView.configure(delta: delta)
            healthDeltaView.isHidden = false
        } else {
            healthDeltaView.isHidden = true
        }
    }
}

// MARK: - Health Delta Badge

@available(iOSApplicationExtension 18.0, *)
final class HealthDeltaBadge: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true

        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
    }

    func configure(delta: Float) {
        let sign = delta >= 0 ? "+" : ""
        label.text = "\(sign)\(Int(delta * 100))%"
        backgroundColor = delta >= 0
            ? UIColor(red: 0.2, green: 0.7, blue: 0.45, alpha: 1)
            : UIColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1)
    }
}

// MARK: - Thinking Indicator View

@available(iOSApplicationExtension 18.0, *)
final class ThinkingIndicatorView: UIView {

    private let dotStack = UIStackView()
    private var dots: [UIView] = []
    private var dotAnimations: [Bool] = [false, false, false]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        dotStack.axis = .horizontal
        dotStack.spacing = 4
        dotStack.alignment = .center
        dotStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotStack)
        NSLayoutConstraint.activate([
            dotStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            dotStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            dotStack.topAnchor.constraint(equalTo: topAnchor),
            dotStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for i in 0..<3 {
            let dot = UIView()
            dot.backgroundColor = UIColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.8)
            dot.layer.cornerRadius = 3
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dotStack.addArrangedSubview(dot)
            dots.append(dot)
            _ = i
        }
    }

    func startAnimating() {
        for (i, dot) in dots.enumerated() {
            let delay = Double(i) * 0.18
            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                options: [.repeat, .autoreverse, .curveEaseInOut]
            ) {
                dot.transform = CGAffineTransform(translationX: 0, y: -4)
                dot.alpha = 1.0
            }
        }
    }

    func stopAnimating() {
        dots.forEach {
            $0.layer.removeAllAnimations()
            $0.transform = .identity
            $0.alpha = 0.5
        }
    }
}
