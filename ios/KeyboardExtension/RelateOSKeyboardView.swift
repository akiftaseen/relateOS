// RelateOSKeyboardView.swift
// SwiftUI-hosted keyboard surface using system glass/material styles

import UIKit
import SwiftUI

// MARK: - Delegate Protocol

@MainActor
@available(iOSApplicationExtension 18.0, *)
protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: RelateOSKeyboardView, didTapKey key: KeyModel)
    func keyboardViewDidTapGlobe(_ view: RelateOSKeyboardView)
}

// MARK: - Key Model

struct KeyModel: Identifiable {
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

    let id: String
    let type: KeyType
    var displayLabel: String
    var isWide: Bool = false
    var isSpecial: Bool = false
    var width: CGFloat? = nil

    var isPrimaryAction: Bool {
        if case .return = type {
            return true
        }
        return false
    }
}

// MARK: - Keyboard Mode

enum KeyboardMode {
    case alpha
    case alphaShifted
    case alphaCapsLock
    case numeric
    case symbols
    case emoji
}

// MARK: - Main Keyboard View

@available(iOSApplicationExtension 18.0, *)
final class RelateOSKeyboardView: UIView {

    weak var delegate: KeyboardViewDelegate?
    unowned let hostInputViewController: UIInputViewController

    private let state = KeyboardGlassState()
    private var hostingController: UIHostingController<KeyboardGlassRootView>?

    init(inputViewController: UIInputViewController, delegate: KeyboardViewDelegate) {
        self.hostInputViewController = inputViewController
        self.delegate = delegate
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        backgroundColor = .clear

        let rootView = KeyboardGlassRootView(
            state: state,
            onKeyTap: { [weak self] key in
                guard let self else { return }
                if case .nextKeyboard = key.type {
                    self.delegate?.keyboardViewDidTapGlobe(self)
                    return
                }
                self.delegate?.keyboardView(self, didTapKey: key)
            }
        )

        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = host

        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func toggleShift() {
        state.toggleShift()
    }

    func switchToNumericMode() {
        state.currentMode = .numeric
    }

    func switchToAlphaMode() {
        state.currentMode = .alpha
    }

    func consumeSingleShiftIfNeeded() {
        state.consumeSingleShiftIfNeeded()
    }

    func switchToEmojiMode() {
        hostInputViewController.advanceToNextInputMode()
    }

    func updateForOrientation(isLandscape: Bool) {
        state.isLandscape = isLandscape
    }
}

// MARK: - SwiftUI State

@available(iOSApplicationExtension 18.0, *)
    private final class KeyboardGlassState: ObservableObject {
    @Published var currentMode: KeyboardMode = .alpha
    @Published var isLandscape = false

    private var shiftTapCount = 0
    private var lastShiftTapTime: Date?

      let keySpacing: CGFloat = 5
      let rowSpacing: CGFloat = 8
    let cornerRadius: CGFloat = 7.5

    var keyHeight: CGFloat {
          isLandscape ? 38 : 50
    }

    func keyHeightForRow(_ rowIndex: Int) -> CGFloat {
        // Bottom row (space bar row) is taller
        let isBottomRow = rowIndex == (currentMode == .numeric ? 3 : 3)
        if isBottomRow && !isLandscape {
            return 56
        }
        return keyHeight
    }

    func toggleShift() {
        let now = Date()
        if let last = lastShiftTapTime, now.timeIntervalSince(last) < 0.4 {
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
    }

    func consumeSingleShiftIfNeeded() {
        guard currentMode == .alphaShifted else { return }
        currentMode = .alpha
    }

    var rows: [[KeyModel]] {
        switch currentMode {
        case .alpha, .alphaShifted, .alphaCapsLock:
            return alphaRows(shifted: currentMode != .alpha)
        case .numeric, .symbols, .emoji:
            return numericRows()
        }
    }

    func rowHorizontalInsets(_ rowIndex: Int) -> CGFloat {
        switch rowIndex {
        case 1: return 16
        case 2: return 8
        default: return 0
        }
    }

    func accessibilityLabel(for model: KeyModel) -> String {
        switch model.type {
        case .character(let value):
            return value
        case .space:
            return "Space"
        case .delete:
            return "Delete"
        case .return:
            return "Return"
        case .nextKeyboard:
            return "Next keyboard"
        case .dismissKeyboard:
            return "Dismiss keyboard"
        case .shift:
            return "Shift"
        case .switchToNumeric:
            return "Numbers"
        case .switchToAlpha:
            return "Letters"
        case .emoji:
            return "Emoji"
        }
    }

    private func alphaRows(shifted: Bool) -> [[KeyModel]] {
        let row1Chars = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let row2Chars = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let row3Chars = ["z", "x", "c", "v", "b", "n", "m"]

        func charKey(_ s: String, row: Int, index: Int) -> KeyModel {
            let value = shifted ? s.uppercased() : s
            return KeyModel(
                id: "alpha-\(row)-\(index)-\(value)",
                type: .character(value),
                displayLabel: value
            )
        }

        let row1 = row1Chars.enumerated().map { charKey($0.element, row: 1, index: $0.offset) }
        let row2 = row2Chars.enumerated().map { charKey($0.element, row: 2, index: $0.offset) }

        var row3: [KeyModel] = []
        row3.append(KeyModel(
            id: "alpha-shift",
            type: .shift,
            displayLabel: shifted ? "⇪" : "⇧",
            isSpecial: true,
            width: 46
        ))
        row3.append(contentsOf: row3Chars.enumerated().map { charKey($0.element, row: 3, index: $0.offset) })
        row3.append(KeyModel(
            id: "alpha-delete",
            type: .delete,
            displayLabel: "⌫",
            isSpecial: true,
            width: 46
        ))

        let row4: [KeyModel] = [
              KeyModel(id: "alpha-123", type: .switchToNumeric, displayLabel: "123", isSpecial: true, width: 48),
            KeyModel(id: "alpha-space", type: .space, displayLabel: "space", isWide: true),
              KeyModel(id: "alpha-return", type: .return, displayLabel: "return", isSpecial: true, width: 96)
        ]

        return [row1, row2, row3, row4]
    }

    private func numericRows() -> [[KeyModel]] {
        let row1Chars = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        let row2Chars = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
        let row3Chars = [".", ",", "?", "!", "'"]

        func charKey(_ s: String, row: Int, index: Int) -> KeyModel {
            KeyModel(id: "num-\(row)-\(index)-\(s)", type: .character(s), displayLabel: s)
        }

        let row1 = row1Chars.enumerated().map { charKey($0.element, row: 1, index: $0.offset) }
        let row2 = row2Chars.enumerated().map { charKey($0.element, row: 2, index: $0.offset) }

        var row3: [KeyModel] = []
          row3.append(KeyModel(id: "num-symbol", type: .switchToNumeric, displayLabel: "#+=", isSpecial: true, width: 48))
        row3.append(contentsOf: row3Chars.enumerated().map { charKey($0.element, row: 3, index: $0.offset) })
          row3.append(KeyModel(id: "num-delete", type: .delete, displayLabel: "⌫", isSpecial: true, width: 48))

        let row4: [KeyModel] = [
              KeyModel(id: "num-abc", type: .switchToAlpha, displayLabel: "ABC", isSpecial: true, width: 48),
            KeyModel(id: "num-space", type: .space, displayLabel: "space", isWide: true),
              KeyModel(id: "num-return", type: .return, displayLabel: "return", isSpecial: true, width: 96)
        ]

        return [row1, row2, row3, row4]
    }
}

// MARK: - SwiftUI Views

@available(iOSApplicationExtension 18.0, *)
private struct KeyboardGlassRootView: View {
    @ObservedObject var state: KeyboardGlassState
    let onKeyTap: (KeyModel) -> Void

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 26.0, *) {
                GlassEffectContainer {
                    keyboardBody
                }
            } else {
                keyboardBody
            }
        }
        .onAppear {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Intentionally left for future state-driven fallback handling.
            }
        }
    }

    private var keyboardBody: some View {
        VStack(spacing: state.rowSpacing) {
            ForEach(Array(state.rows.enumerated()), id: \.offset) { rowIndex, rowModels in
                HStack(spacing: state.keySpacing) {
                    ForEach(rowModels) { key in
                        KeyboardGlassKeyView(
                            key: key,
                            cornerRadius: state.cornerRadius,
                            accessibilityLabel: state.accessibilityLabel(for: key),
                            onTap: { onKeyTap(key) }
                        )
                    }
                }
                .padding(.horizontal, state.rowHorizontalInsets(rowIndex))
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct KeyboardGlassKeyView: View {
    let key: KeyModel
    let cornerRadius: CGFloat
    let accessibilityLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(key.displayLabel)
                .font(keyFont)
                .foregroundStyle(key.isPrimaryAction ? Color.white : Color(uiColor: .label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyboardKeyButtonStyle(isPrimary: key.isPrimaryAction, isSpecial: key.isSpecial, cornerRadius: cornerRadius))
        .accessibilityLabel(accessibilityLabel)
        .frame(maxWidth: key.isWide ? .infinity : nil)
        .frame(width: key.width)
    }

    private var keyFont: Font {
        if key.isWide || key.isSpecial {
            return .system(size: 16, weight: .regular)
        }
        return .system(size: 25, weight: .regular)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct KeyboardKeyButtonStyle: ButtonStyle {
    let isPrimary: Bool
    let isSpecial: Bool
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if isPrimary {
                        Color.blue
                    } else if isSpecial {
                        Color(uiColor: .systemGray4)
                    } else {
                        Color(uiColor: .systemBackground)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 1.0)
            .scaleEffect(configuration.isPressed ? 1.15 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
            .zIndex(configuration.isPressed ? 100 : 0)
    }
}
