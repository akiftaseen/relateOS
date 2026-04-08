// RelateOSKeyboardView.swift
// iOS 26 Liquid Glass Key Layout — QWERTY + Cangjie/Jyutping toggle

import UIKit

// MARK: - Delegate Protocol

@available(iOSApplicationExtension 18.0, *)
protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: RelateOSKeyboardView, didTapKey key: KeyModel)
    func keyboardViewDidTapGlobe(_ view: RelateOSKeyboardView)
}

// MARK: - Key Model

struct KeyModel {
    enum KeyType {
        case character(String)
        case space
        case delete
        case `return`
        case nextKeyboard
        case dismissKeyboard
        case shift
        case switchToNumeric
        case switchToAlpha
        case emoji
    }

    let type: KeyType
    var displayLabel: String
    var isWide: Bool = false
    var isSpecial: Bool = false
    var width: CGFloat? = nil  // override for custom widths
}

// MARK: - Keyboard Mode

enum KeyboardMode {
    case alpha, alphaShifted, alphaCapsLock, numeric, symbols, emoji
}

// MARK: - Main Keyboard View

@available(iOSApplicationExtension 18.0, *)
final class RelateOSKeyboardView: UIView {

    // MARK: - Properties

    weak var delegate: KeyboardViewDelegate?
    unowned let hostInputViewController: UIInputViewController

    private var currentMode: KeyboardMode = .alpha
    private var isShiftHeld = false
    private var shiftTapCount = 0
    private var lastShiftTapTime: Date?

    private var keyRows: [[KeyButton]] = []
    private var stackView: UIStackView!
    private var spaceBarView: SpaceBarView!

    // iOS 26 — glass effect container
    private var glassContainer: UIVisualEffectView!

    // Layout constants
    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 8
    private let keyHeight: CGFloat = 44
    private let cornerRadius: CGFloat = 9

    // MARK: - Init

    init(inputViewController: UIInputViewController, delegate: KeyboardViewDelegate) {
        self.hostInputViewController = inputViewController
        self.delegate = delegate
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        backgroundColor = .clear
        setupGlassBackground()
        buildAlphaLayout()
    }

    private func setupGlassBackground() {
        // iOS 26 Liquid Glass — UIBlurEffect with new .liquid style
        let blurStyle: UIBlurEffect.Style
        if #available(iOSApplicationExtension 26.0, *) {
            // iOS 26 introduces new blur styles
            blurStyle = .systemUltraThinMaterial
        } else {
            blurStyle = .systemUltraThinMaterial
        }

        let blurEffect = UIBlurEffect(style: blurStyle)
        glassContainer = UIVisualEffectView(effect: blurEffect)
        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.layer.cornerRadius = 0
        glassContainer.clipsToBounds = true
        addSubview(glassContainer)

        NSLayoutConstraint.activate([
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassContainer.topAnchor.constraint(equalTo: topAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Layout Building

    private func buildAlphaLayout() {
        clearExistingKeys()

        let rows = alphaRows(shifted: currentMode == .alphaShifted || currentMode == .alphaCapsLock)
        buildRowStack(rows: rows)
    }

    private func buildNumericLayout() {
        clearExistingKeys()
        buildRowStack(rows: numericRows())
    }

    private func clearExistingKeys() {
        keyRows.forEach { row in row.forEach { $0.removeFromSuperview() } }
        keyRows.removeAll()
        stackView?.removeFromSuperview()
    }

    private func buildRowStack(rows: [[KeyModel]]) {
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = rowSpacing
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for rowModels in rows {
            let rowView = buildRow(models: rowModels)
            stackView.addArrangedSubview(rowView)
            rowView.heightAnchor.constraint(equalToConstant: keyHeight).isActive = true
        }

        glassContainer.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: glassContainer.contentView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: glassContainer.contentView.trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: glassContainer.contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: glassContainer.contentView.bottomAnchor, constant: -8)
        ])
    }

    private func buildRow(models: [KeyModel]) -> UIView {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = keySpacing
        rowStack.distribution = .fill
        rowStack.alignment = .fill

        var rowButtons: [KeyButton] = []

        for model in models {
            let button = KeyButton(model: model, cornerRadius: cornerRadius)
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)

            // Handle delete long press
            if case .delete = model.type {
                let longPress = UILongPressGestureRecognizer(
                    target: self,
                    action: #selector(deleteKeyLongPress(_:))
                )
                longPress.minimumPressDuration = 0.4
                button.addGestureRecognizer(longPress)
            }

            // Width constraints
            if let fixedWidth = model.width {
                button.widthAnchor.constraint(equalToConstant: fixedWidth).isActive = true
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
            } else if model.isWide {
                // Wide keys use flexible spacers — handled via intrinsic sizing
                button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            } else {
                button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            }

            rowStack.addArrangedSubview(button)
            rowButtons.append(button)
        }

        keyRows.append(rowButtons)
        return rowStack
    }

    // MARK: - Key Actions

    @objc private func keyTapped(_ button: KeyButton) {
        button.animateTap()
        delegate?.keyboardView(self, didTapKey: button.model)

        // Track shift state
        if case .shift = button.model.type {
            return // handled in toggleShift()
        }
    }

    @objc private func keyTouchDown(_ button: KeyButton) {
        button.animatePress()
        // Popup callout for alpha keys
        if case .character = button.model.type {
            showCallout(for: button)
        }
    }

    private var activeCallout: KeyCalloutView?

    private func showCallout(for button: KeyButton) {
        activeCallout?.dismiss()
        let callout = KeyCalloutView(button: button)
        superview?.addSubview(callout)
        callout.show()
        activeCallout = callout

        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak callout] in
            callout?.dismiss()
        }
    }

    private var deleteTimer: Timer?

    @objc private func deleteKeyLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let deleteKey = KeyModel(type: .delete, displayLabel: "⌫")
                self.delegate?.keyboardView(self, didTapKey: deleteKey)
            }
        case .ended, .cancelled:
            deleteTimer?.invalidate()
            deleteTimer = nil
        default:
            break
        }
    }

    // MARK: - Mode Switching

    func toggleShift() {
        let now = Date()
        if let lastTap = lastShiftTapTime,
           now.timeIntervalSince(lastTap) < 0.4 {
            shiftTapCount += 1
        } else {
            shiftTapCount = 1
        }
        lastShiftTapTime = now

        if shiftTapCount >= 2 {
            currentMode = .alphaCapsLock
            shiftTapCount = 0
        } else {
            currentMode = currentMode == .alphaShifted ? .alpha : .alphaShifted
        }

        buildAlphaLayout()
        updateShiftButtonAppearance()
    }

    func switchToNumericMode() {
        currentMode = .numeric
        buildNumericLayout()
    }

    func switchToAlphaMode() {
        currentMode = .alpha
        buildAlphaLayout()
    }

    func switchToEmojiMode() {
        // Advance to system emoji keyboard
        hostInputViewController.advanceToNextInputMode()
    }

    private func updateShiftButtonAppearance() {
        // Find shift button and update its visual state
        for row in keyRows {
            for button in row {
                if case .shift = button.model.type {
                    button.updateShiftState(currentMode)
                }
            }
        }
    }

    // MARK: - Orientation

    func updateForOrientation(isLandscape: Bool) {
        // Adjust key heights for landscape
        let newHeight: CGFloat = isLandscape ? 32 : 44
        for rowView in stackView.arrangedSubviews {
            rowView.constraints.first(where: { $0.firstAttribute == .height })?.constant = newHeight
        }
        layoutIfNeeded()
    }

    // MARK: - Key Definitions

    private func alphaRows(shifted: Bool) -> [[KeyModel]] {
        let row1Chars = ["q","w","e","r","t","y","u","i","o","p"]
        let row2Chars = ["a","s","d","f","g","h","j","k","l"]
        let row3Chars = ["z","x","c","v","b","n","m"]

        func charKey(_ s: String) -> KeyModel {
            KeyModel(type: .character(shifted ? s.uppercased() : s),
                     displayLabel: shifted ? s.uppercased() : s)
        }

        let row1 = row1Chars.map { charKey($0) }

        let row2 = row2Chars.map { charKey($0) }

        var row3: [KeyModel] = []
        row3.append(KeyModel(type: .shift, displayLabel: shifted ? "⇪" : "⇧",
                             isSpecial: true, width: 42))
        row3.append(contentsOf: row3Chars.map { charKey($0) })
        row3.append(KeyModel(type: .delete, displayLabel: "⌫",
                             isSpecial: true, width: 42))

        let row4: [KeyModel] = [
            KeyModel(type: .switchToNumeric, displayLabel: "123", isSpecial: true, width: 44),
            KeyModel(type: .nextKeyboard,    displayLabel: "🌐", isSpecial: true, width: 44),
            KeyModel(type: .space,           displayLabel: "空格", isWide: true),
            KeyModel(type: .return,          displayLabel: "換行", isSpecial: true, width: 88)
        ]

        return [row1, row2, row3, row4]
    }

    private func numericRows() -> [[KeyModel]] {
        let row1Chars = ["1","2","3","4","5","6","7","8","9","0"]
        let row2Chars = ["-","/",":",";","(",")",  "$","&","@","\""]
        let row3Chars = [".",",","?","!","'"]

        func charKey(_ s: String) -> KeyModel {
            KeyModel(type: .character(s), displayLabel: s)
        }

        let row1 = row1Chars.map { charKey($0) }
        let row2 = row2Chars.map { charKey($0) }

        var row3: [KeyModel] = []
        row3.append(KeyModel(type: .switchToNumeric, displayLabel: "#+=",
                             isSpecial: true, width: 44))
        row3.append(contentsOf: row3Chars.map { charKey($0) })
        row3.append(KeyModel(type: .delete, displayLabel: "⌫",
                             isSpecial: true, width: 44))

        let row4: [KeyModel] = [
            KeyModel(type: .switchToAlpha, displayLabel: "ABC", isSpecial: true, width: 44),
            KeyModel(type: .nextKeyboard,  displayLabel: "🌐", isSpecial: true, width: 44),
            KeyModel(type: .space,         displayLabel: "空格", isWide: true),
            KeyModel(type: .return,        displayLabel: "換行", isSpecial: true, width: 88)
        ]

        return [row1, row2, row3, row4]
    }
}

@available(iOSApplicationExtension 18.0, *)
final class SpaceBarView: UIControl {

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        clipsToBounds = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        label.text = "空格"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - KeyButton

@available(iOSApplicationExtension 18.0, *)
final class KeyButton: UIButton {

    let model: KeyModel
    private let cornerRadius: CGFloat

    private var glassLayer: CALayer?

    init(model: KeyModel, cornerRadius: CGFloat) {
        self.model = model
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = false

        // iOS 26 Liquid Glass style key background
        applyLiquidGlassStyle()

        // Label
        setTitle(model.displayLabel, for: .normal)
        titleLabel?.font = keyFont()
        setTitleColor(keyTextColor(), for: .normal)
        setTitleColor(keyTextColor().withAlphaComponent(0.5), for: .highlighted)
    }

    private func applyLiquidGlassStyle() {
        if model.isSpecial {
            // Special keys: darker glass
            backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.12)
                    : UIColor.black.withAlphaComponent(0.15)
            }
        } else {
            // Regular keys: lighter glass with subtle highlight
            backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.22)
                    : UIColor.white.withAlphaComponent(0.85)
            }
        }

        // Subtle shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1.5)
        layer.shadowRadius = 1.5
        layer.shadowOpacity = 0.18

        // Top highlight for glass effect
        addGlassHighlight()
    }

    private func addGlassHighlight() {
        let highlight = CAGradientLayer()
        highlight.colors = [
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        highlight.startPoint = CGPoint(x: 0.5, y: 0)
        highlight.endPoint = CGPoint(x: 0.5, y: 0.5)
        highlight.cornerRadius = cornerRadius
        layer.addSublayer(highlight)
        glassLayer = highlight
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glassLayer?.frame = bounds
    }

    private func keyFont() -> UIFont {
        if model.isWide || model.isSpecial {
            return .systemFont(ofSize: 15, weight: .medium)
        }
        return .systemFont(ofSize: 22, weight: .light)
    }

    private func keyTextColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.12, alpha: 1)
        }
    }

    func animateTap() {
        UIView.animate(withDuration: 0.06, animations: {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.alpha = 0.7
        }) { _ in
            UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 0.8) {
                self.transform = .identity
                self.alpha = 1.0
            }
        }
    }

    func animatePress() {
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func updateShiftState(_ mode: KeyboardMode) {
        switch mode {
        case .alphaShifted:
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
            setTitle("⇧", for: .normal)
        case .alphaCapsLock:
            backgroundColor = UIColor.systemBlue
            setTitle("⇪", for: .normal)
        default:
            configure()
        }
    }
}

// MARK: - Key Callout View (iOS 26 Liquid Glass popup)

@available(iOSApplicationExtension 18.0, *)
final class KeyCalloutView: UIView {

    private let label = UILabel()
    private weak var sourceButton: KeyButton?

    init(button: KeyButton) {
        self.sourceButton = button
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.layer.cornerRadius = 10
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        label.font = .systemFont(ofSize: 28, weight: .light)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        if let button = sourceButton {
            if case .character(let ch) = button.model.type {
                label.text = ch.uppercased()
            }

            // Position above button
            guard let superview = button.superview else { return }
            let buttonFrame = superview.convert(button.frame, to: nil)
            frame = CGRect(
                x: buttonFrame.midX - 22,
                y: buttonFrame.minY - 52,
                width: 44,
                height: 48
            )
        }

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    func show() {
        UIView.animate(withDuration: 0.12, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.1) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
