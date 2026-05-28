import Carbon
import Foundation

struct HotKeyConfig: Equatable {
    var key: String
    var modifiers: Int

    static let defaultKey = "F"
    static let defaultModifiers = Int(optionKey)

    static var current: HotKeyConfig {
        let storedKey = UserDefaults.standard.string(forKey: PreferenceKeys.hotKeyKey) ?? defaultKey
        let key = sanitizedKey(storedKey) ?? defaultKey
        let modifiers = UserDefaults.standard.integer(forKey: PreferenceKeys.hotKeyModifiers)
        return HotKeyConfig(key: key, modifiers: modifiers == 0 ? defaultModifiers : modifiers)
    }

    var keyCode: UInt32? {
        Self.keyCode(for: key)
    }

    var carbonModifiers: UInt32 {
        UInt32(modifiers)
    }

    var displayString: String {
        let symbols = HotKeyModifierOption.allCases
            .filter { modifiers & $0.carbonValue != 0 }
            .map(\.symbol)
            .joined()
        return "\(symbols)\(key.uppercased())"
    }

    static func sanitizedKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let first = trimmed.first, first.isLetter || first.isNumber else {
            return nil
        }
        return String(first)
    }

    static func keyCode(for key: String) -> UInt32? {
        switch key.uppercased() {
        case "A": return UInt32(kVK_ANSI_A)
        case "B": return UInt32(kVK_ANSI_B)
        case "C": return UInt32(kVK_ANSI_C)
        case "D": return UInt32(kVK_ANSI_D)
        case "E": return UInt32(kVK_ANSI_E)
        case "F": return UInt32(kVK_ANSI_F)
        case "G": return UInt32(kVK_ANSI_G)
        case "H": return UInt32(kVK_ANSI_H)
        case "I": return UInt32(kVK_ANSI_I)
        case "J": return UInt32(kVK_ANSI_J)
        case "K": return UInt32(kVK_ANSI_K)
        case "L": return UInt32(kVK_ANSI_L)
        case "M": return UInt32(kVK_ANSI_M)
        case "N": return UInt32(kVK_ANSI_N)
        case "O": return UInt32(kVK_ANSI_O)
        case "P": return UInt32(kVK_ANSI_P)
        case "Q": return UInt32(kVK_ANSI_Q)
        case "R": return UInt32(kVK_ANSI_R)
        case "S": return UInt32(kVK_ANSI_S)
        case "T": return UInt32(kVK_ANSI_T)
        case "U": return UInt32(kVK_ANSI_U)
        case "V": return UInt32(kVK_ANSI_V)
        case "W": return UInt32(kVK_ANSI_W)
        case "X": return UInt32(kVK_ANSI_X)
        case "Y": return UInt32(kVK_ANSI_Y)
        case "Z": return UInt32(kVK_ANSI_Z)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        default: return nil
        }
    }
}

enum HotKeyModifierOption: Int, CaseIterable, Identifiable {
    case command
    case option
    case control
    case shift

    var id: Int { rawValue }

    var carbonValue: Int {
        switch self {
        case .command: return Int(cmdKey)
        case .option: return Int(optionKey)
        case .control: return Int(controlKey)
        case .shift: return Int(shiftKey)
        }
    }

    var label: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
}

private extension Character {
    var isLetter: Bool {
        unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    var isNumber: Bool {
        unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}
