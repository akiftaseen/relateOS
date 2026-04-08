import UIKit
import ObjectiveC

private enum GlassAssociatedKeys {
    static var specular: UInt8 = 0
}

func makeLiquidGlassSurface(
    cornerRadius: CGFloat = 18,
    blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial,
    tintAlpha: CGFloat = 0.08,
    borderAlpha: CGFloat = 0.40,
    addSpecular: Bool = true
) -> UIVisualEffectView {
    let fx = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    fx.translatesAutoresizingMaskIntoConstraints = false
    fx.layer.cornerRadius = cornerRadius
    fx.layer.cornerCurve = .continuous
    fx.clipsToBounds = true
    fx.layer.borderWidth = 1
    fx.layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
    fx.layer.shadowColor = UIColor.black.cgColor
    fx.layer.shadowOpacity = 0.18
    fx.layer.shadowRadius = 16
    fx.layer.shadowOffset = CGSize(width: 0, height: 6)
    fx.layer.masksToBounds = false

    let tintView = UIView()
    tintView.backgroundColor = UIColor.white.withAlphaComponent(tintAlpha)
    tintView.translatesAutoresizingMaskIntoConstraints = false
    fx.contentView.addSubview(tintView)
    NSLayoutConstraint.activate([
        tintView.leadingAnchor.constraint(equalTo: fx.contentView.leadingAnchor),
        tintView.trailingAnchor.constraint(equalTo: fx.contentView.trailingAnchor),
        tintView.topAnchor.constraint(equalTo: fx.contentView.topAnchor),
        tintView.bottomAnchor.constraint(equalTo: fx.contentView.bottomAnchor)
    ])

    if addSpecular {
        let spec = CAGradientLayer()
        spec.colors = [
            UIColor.white.withAlphaComponent(0.55).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        spec.startPoint = CGPoint(x: 0.5, y: 0)
        spec.endPoint = CGPoint(x: 0.5, y: 1)
        spec.locations = [0, 0.5]
        spec.cornerRadius = cornerRadius
        fx.layer.addSublayer(spec)
        objc_setAssociatedObject(fx, &GlassAssociatedKeys.specular, spec, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    return fx
}

func updateSpecularFrame(for surface: UIVisualEffectView) {
    guard let spec = objc_getAssociatedObject(surface, &GlassAssociatedKeys.specular) as? CAGradientLayer else { return }
    spec.frame = CGRect(x: 0, y: 0, width: surface.bounds.width, height: min(surface.bounds.height * 0.40, 44))
}

final class LiquidGlassKey: UIButton {
    private let glassFX: UIVisualEffectView

    init(title: String, fontSize: CGFloat = 16, isFunctional: Bool = false) {
        glassFX = makeLiquidGlassSurface(
            cornerRadius: 12,
            blurStyle: isFunctional ? .systemThinMaterial : .systemUltraThinMaterial,
            tintAlpha: isFunctional ? 0.14 : 0.06,
            borderAlpha: 0.35,
            addSpecular: true
        )
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassFX)
        glassFX.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glassFX.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassFX.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassFX.topAnchor.constraint(equalTo: topAnchor),
            glassFX.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        label.textColor = .label
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        glassFX.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: glassFX.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: glassFX.contentView.centerYAnchor)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSpecularFrame(for: glassFX)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: glassFX.layer.cornerRadius).cgPath
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.08, delay: 0, options: .curveEaseIn) {
            self.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 4) {
            self.transform = .identity
        }
    }
}

final class LiquidGlassSuggestionChip: UIButton {
    private let glassFX: UIVisualEffectView

    init(text: String) {
        glassFX = makeLiquidGlassSurface(
            cornerRadius: 22,
            blurStyle: .systemMaterial,
            tintAlpha: 0.12,
            borderAlpha: 0.45,
            addSpecular: true
        )
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassFX)
        glassFX.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glassFX.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassFX.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassFX.topAnchor.constraint(equalTo: topAnchor),
            glassFX.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        glassFX.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: glassFX.contentView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: glassFX.contentView.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: glassFX.contentView.centerYAnchor)
        ])

        addTarget(self, action: #selector(bounce), for: .touchDown)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSpecularFrame(for: glassFX)
    }

    @objc private func bounce() {
        UIView.animate(withDuration: 0.10, delay: 0, options: .curveEaseIn) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            UIView.animate(withDuration: 0.26, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 6) {
                self.transform = .identity
            }
        }
    }
}

class KeyboardViewController: UIInputViewController {
    
    private var glassBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let contentContainerView = UIView()
    private let assistantBubbleButton = UIButton(type: .system)
    private var assistantPanelView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let assistantPanelContentView = UIView()
    private var assistantPanelHeightConstraint: NSLayoutConstraint?
    private var assistantPanelCollapsed = false
    private let suggestionsStackView = UIStackView()
    private let controlsStackView = UIStackView()
    private let keyboardRowsStackView = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let subtextLabel = UILabel()
    private var messageCache: [String] = []
    private let maxCacheSize = 20
    private var suggestionTexts: [Int: String] = [:]
    private var controlsTexts: [Int: String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSpecularFrame(for: glassBackgroundView)
        updateSpecularFrame(for: assistantPanelView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func setupUI() {
        view.backgroundColor = .clear

        glassBackgroundView = makeLiquidGlassSurface(
            cornerRadius: 22,
            blurStyle: .systemUltraThinMaterial,
            tintAlpha: 0.05,
            borderAlpha: 0.30,
            addSpecular: false
        )
        view.addSubview(glassBackgroundView)

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.backgroundColor = .clear
        glassBackgroundView.contentView.addSubview(contentContainerView)

        assistantBubbleButton.translatesAutoresizingMaskIntoConstraints = false
        assistantBubbleButton.setTitle("◉", for: .normal)
        assistantBubbleButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        assistantBubbleButton.setTitleColor(.label, for: .normal)
        assistantBubbleButton.addTarget(self, action: #selector(toggleAssistantPanel), for: .touchUpInside)
        let orbGlass = makeLiquidGlassSurface(
            cornerRadius: 22,
            blurStyle: .systemMaterial,
            tintAlpha: 0.18,
            borderAlpha: 0.55,
            addSpecular: true
        )
        assistantBubbleButton.insertSubview(orbGlass, at: 0)
        NSLayoutConstraint.activate([
            orbGlass.leadingAnchor.constraint(equalTo: assistantBubbleButton.leadingAnchor),
            orbGlass.trailingAnchor.constraint(equalTo: assistantBubbleButton.trailingAnchor),
            orbGlass.topAnchor.constraint(equalTo: assistantBubbleButton.topAnchor),
            orbGlass.bottomAnchor.constraint(equalTo: assistantBubbleButton.bottomAnchor)
        ])
        contentContainerView.addSubview(assistantBubbleButton)

        assistantPanelView = makeLiquidGlassSurface(
            cornerRadius: 18,
            blurStyle: .systemThinMaterial,
            tintAlpha: 0.10,
            borderAlpha: 0.40,
            addSpecular: true
        )
        contentContainerView.addSubview(assistantPanelView)

        assistantPanelContentView.translatesAutoresizingMaskIntoConstraints = false
        assistantPanelContentView.backgroundColor = .clear
        assistantPanelView.contentView.addSubview(assistantPanelContentView)
        
        // Setup suggestions stack view
        suggestionsStackView.axis = .horizontal
        suggestionsStackView.distribution = .fillEqually
        suggestionsStackView.spacing = 8
        suggestionsStackView.translatesAutoresizingMaskIntoConstraints = false
        assistantPanelContentView.addSubview(suggestionsStackView)

        // Setup controls row (fallback keys so keyboard is always usable)
        controlsStackView.axis = .horizontal
        controlsStackView.distribution = .fill
        controlsStackView.spacing = 8
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        assistantPanelContentView.addSubview(controlsStackView)

        // Main QWERTY rows
        keyboardRowsStackView.axis = .vertical
        keyboardRowsStackView.distribution = .fillEqually
        keyboardRowsStackView.spacing = 7
        keyboardRowsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(keyboardRowsStackView)
        
        // Setup loading indicator
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        assistantPanelContentView.addSubview(loadingIndicator)
        
        // Setup subtext label
        subtextLabel.numberOfLines = 2
        subtextLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subtextLabel.textColor = UIColor.label.withAlphaComponent(0.75)
        subtextLabel.translatesAutoresizingMaskIntoConstraints = false
        assistantPanelContentView.addSubview(subtextLabel)
        
        // Layout constraints
        assistantPanelHeightConstraint = assistantPanelView.heightAnchor.constraint(equalToConstant: 148)
        assistantPanelHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            glassBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            glassBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            glassBackgroundView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            glassBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),

            contentContainerView.leadingAnchor.constraint(equalTo: glassBackgroundView.contentView.leadingAnchor, constant: 10),
            contentContainerView.trailingAnchor.constraint(equalTo: glassBackgroundView.contentView.trailingAnchor, constant: -10),
            contentContainerView.topAnchor.constraint(equalTo: glassBackgroundView.contentView.topAnchor, constant: 10),
            contentContainerView.bottomAnchor.constraint(equalTo: glassBackgroundView.contentView.bottomAnchor, constant: -10),

            assistantBubbleButton.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            assistantBubbleButton.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            assistantBubbleButton.widthAnchor.constraint(equalToConstant: 44),
            assistantBubbleButton.heightAnchor.constraint(equalToConstant: 44),

            assistantPanelView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            assistantPanelView.trailingAnchor.constraint(equalTo: assistantBubbleButton.leadingAnchor, constant: -8),
            assistantPanelView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),

            assistantPanelContentView.leadingAnchor.constraint(equalTo: assistantPanelView.contentView.leadingAnchor, constant: 12),
            assistantPanelContentView.trailingAnchor.constraint(equalTo: assistantPanelView.contentView.trailingAnchor, constant: -12),
            assistantPanelContentView.topAnchor.constraint(equalTo: assistantPanelView.contentView.topAnchor, constant: 10),
            assistantPanelContentView.bottomAnchor.constraint(equalTo: assistantPanelView.contentView.bottomAnchor, constant: -10),

            suggestionsStackView.leadingAnchor.constraint(equalTo: assistantPanelContentView.leadingAnchor),
            suggestionsStackView.trailingAnchor.constraint(equalTo: assistantPanelContentView.trailingAnchor),
            suggestionsStackView.topAnchor.constraint(equalTo: assistantPanelContentView.topAnchor),
            suggestionsStackView.heightAnchor.constraint(equalToConstant: 42),

            controlsStackView.leadingAnchor.constraint(equalTo: assistantPanelContentView.leadingAnchor),
            controlsStackView.trailingAnchor.constraint(equalTo: assistantPanelContentView.trailingAnchor),
            controlsStackView.topAnchor.constraint(equalTo: subtextLabel.bottomAnchor, constant: 8),
            controlsStackView.heightAnchor.constraint(equalToConstant: 42),
            controlsStackView.bottomAnchor.constraint(equalTo: assistantPanelContentView.bottomAnchor),

            keyboardRowsStackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            keyboardRowsStackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            keyboardRowsStackView.topAnchor.constraint(equalTo: assistantPanelView.bottomAnchor, constant: 10),
            keyboardRowsStackView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: assistantPanelContentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: assistantPanelContentView.centerYAnchor),
            
            subtextLabel.leadingAnchor.constraint(equalTo: assistantPanelContentView.leadingAnchor),
            subtextLabel.trailingAnchor.constraint(equalTo: assistantPanelContentView.trailingAnchor),
            subtextLabel.topAnchor.constraint(equalTo: suggestionsStackView.bottomAnchor, constant: 8),
        ])

        // Show initial content immediately so the keyboard never looks blank.
        displaySuggestions([
            SuggestionItem(text: "I hear you", tone: "empathetic"),
            SuggestionItem(text: "Let's talk", tone: "direct"),
            SuggestionItem(text: "No pressure", tone: "supportive")
        ])
        setupControlKeys()
        setupKeyboardRows()
        updateAssistantPanelVisibility()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // Called when text will change
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // Capture context and request suggestions
        captureContext()
    }
    
    private func captureContext() {
        guard let documentContextBeforeInput = textDocumentProxy.documentContextBeforeInput else {
            return
        }
        
        // Extract last 20 messages (simplified - split by newline)
        let messages = documentContextBeforeInput
            .split(separator: "\n", maxSplits: 19, omittingEmptySubsequences: true)
            .map(String.init)
            .reversed()
        
        messageCache = Array(messages.prefix(maxCacheSize))
        
        // Request suggestions from main app via platform channel
        requestSuggestions(messages: messageCache)
    }
    
    private func requestSuggestions(messages: [String]) {
        loadingIndicator.startAnimating()
        
        // TODO: Implement platform channel communication to main app
        // This will call the analyze-intent endpoint through the main app
        
        // For now, show mock suggestions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.displaySuggestions([
                SuggestionItem(text: "I understand", tone: "empathetic"),
                SuggestionItem(text: "Let's talk", tone: "direct"),
                SuggestionItem(text: "No pressure", tone: "supportive")
            ])
        }
    }
    
    private func displaySuggestions(_ suggestions: [SuggestionItem]) {
        loadingIndicator.stopAnimating()
        
        suggestionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        suggestionTexts.removeAll()
        
        for (index, suggestion) in suggestions.prefix(3).enumerated() {
            let button = makeGlassButton(font: UIFont.systemFont(ofSize: 13, weight: .semibold), isFunctional: false)
            button.setTitle(suggestion.text, for: .normal)
            button.tag = index
            suggestionTexts[index] = suggestion.text
            button.addTarget(self, action: #selector(handleSuggestionTap(_:)), for: .touchUpInside)
            
            suggestionsStackView.addArrangedSubview(button)
        }
        
        subtextLabel.text = "Tap a suggestion or continue typing"
    }

    private func setupControlKeys() {
        controlsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        controlsTexts.removeAll()

        let controls: [(String, CGFloat, Int)] = [
            ("🌐", 44, 0),
            ("Space", 138, 1),
            ("⌫", 44, 2),
            ("⏎", 44, 3)
        ]

        for (title, width, tag) in controls {
            let button = makeGlassButton(font: UIFont.systemFont(ofSize: 15, weight: .semibold), isFunctional: true)
            button.setTitle(title, for: .normal)
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
            button.heightAnchor.constraint(equalToConstant: 42).isActive = true
            button.tag = tag
            controlsTexts[tag] = title
            button.addTarget(self, action: #selector(handleControlTap(_:)), for: .touchUpInside)
            controlsStackView.addArrangedSubview(button)
        }
    }

    private func setupKeyboardRows() {
        keyboardRowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rows: [[String]] = [
            ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
            ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
            ["Z", "X", "C", "V", "B", "N", "M"]
        ]

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6

            for key in row {
                let button = makeGlassButton(font: UIFont.systemFont(ofSize: 15, weight: .semibold), isFunctional: false)
                button.setTitle(key, for: .normal)
                button.heightAnchor.constraint(equalToConstant: 42).isActive = true
                button.addTarget(self, action: #selector(handleLetterTap(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(button)
            }

            keyboardRowsStackView.addArrangedSubview(rowStack)
        }

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.distribution = .fill
        bottomRow.spacing = 6

        let emojiButton = makeGlassButton(font: UIFont.systemFont(ofSize: 15, weight: .semibold), isFunctional: true)
        emojiButton.setTitle("🙂", for: .normal)
        emojiButton.widthAnchor.constraint(equalToConstant: 52).isActive = true
        emojiButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        emojiButton.tag = 100
        emojiButton.addTarget(self, action: #selector(handleControlTap(_:)), for: .touchUpInside)

        let spaceButton = makeGlassButton(font: UIFont.systemFont(ofSize: 15, weight: .semibold), isFunctional: false)
        spaceButton.setTitle("Space", for: .normal)
        spaceButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        spaceButton.tag = 101
        spaceButton.addTarget(self, action: #selector(handleControlTap(_:)), for: .touchUpInside)

        let deleteButton = makeGlassButton(font: UIFont.systemFont(ofSize: 15, weight: .semibold), isFunctional: true)
        deleteButton.setTitle("⌫", for: .normal)
        deleteButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        deleteButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        deleteButton.tag = 102
        deleteButton.addTarget(self, action: #selector(handleControlTap(_:)), for: .touchUpInside)

        bottomRow.addArrangedSubview(emojiButton)
        bottomRow.addArrangedSubview(spaceButton)
        bottomRow.addArrangedSubview(deleteButton)
        keyboardRowsStackView.addArrangedSubview(bottomRow)
    }

    @objc private func handleLetterTap(_ sender: UIButton) {
        guard let letter = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(letter.lowercased())
    }

    @objc private func toggleAssistantPanel() {
        assistantPanelCollapsed.toggle()
        updateAssistantPanelVisibility(animated: true)
    }

    private func updateAssistantPanelVisibility(animated: Bool = false) {
        let targetAlpha: CGFloat = assistantPanelCollapsed ? 0.0 : 1.0
        let targetHeight: CGFloat = assistantPanelCollapsed ? 56 : 148

        assistantPanelHeightConstraint?.constant = targetHeight

        let changes = {
            self.suggestionsStackView.alpha = self.assistantPanelCollapsed ? 0.0 : 1.0
            self.controlsStackView.alpha = self.assistantPanelCollapsed ? 0.0 : 1.0
            self.subtextLabel.alpha = self.assistantPanelCollapsed ? 0.0 : 1.0
            self.loadingIndicator.alpha = self.assistantPanelCollapsed ? 0.0 : 1.0
            self.assistantPanelView.alpha = targetAlpha
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    private func makeGlassButton(font: UIFont, isFunctional: Bool) -> UIButton {
        let button = UIButton(type: .system)
        let glass = makeLiquidGlassSurface(
            cornerRadius: isFunctional ? 12 : 10,
            blurStyle: isFunctional ? .systemThinMaterial : .systemUltraThinMaterial,
            tintAlpha: isFunctional ? 0.14 : 0.06,
            borderAlpha: 0.35,
            addSpecular: true
        )
        button.addSubview(glass)
        glass.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            glass.topAnchor.constraint(equalTo: button.topAnchor),
            glass.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        button.titleLabel?.font = font
        button.setTitleColor(UIColor.label, for: .normal)
        button.backgroundColor = .clear
        button.clipsToBounds = false
        return button
    }

    @objc private func handleControlTap(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            advanceToNextInputMode()
        case 1:
            textDocumentProxy.insertText(" ")
        case 2, 102:
            textDocumentProxy.deleteBackward()
        case 3:
            textDocumentProxy.insertText("\n")
        case 100:
            insertSuggestion("🙂")
        default:
            break
        }
    }
    
    private func insertSuggestion(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    @objc private func handleSuggestionTap(_ sender: UIButton) {
        if let text = suggestionTexts[sender.tag] {
            insertSuggestion(text)
        }
    }
}

struct SuggestionItem {
    let text: String
    let tone: String
}
