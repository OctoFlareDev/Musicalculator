import Combine
import Foundation

enum MusicTiming {
    /// BPM is defined in quarter notes, so one token advances by exactly one beat.
    static func quarterNoteNanoseconds(bpm: Int) -> UInt64 {
        UInt64((60.0 / Double(max(bpm, 1))) * 1_000_000_000)
    }
}

struct MusicToken: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case note
        case rest
        case tempo
        case symbol
    }

    var id = UUID()
    var kind: Kind
    var value: Int = 0
    var isSharp = false
    var restCount = 1
    var tempoBPM: Int?
    var symbol: String?

    static func note(_ value: Int, sharp: Bool) -> MusicToken {
        MusicToken(kind: .note, value: value, isSharp: sharp)
    }

    static func rest(count: Int = 1) -> MusicToken {
        MusicToken(kind: .rest, restCount: count)
    }

    static func tempo(_ bpm: Int) -> MusicToken {
        MusicToken(kind: .tempo, tempoBPM: bpm)
    }

    static func symbol(_ symbol: String, sharp: Bool = false) -> MusicToken {
        MusicToken(kind: .symbol, isSharp: sharp, symbol: symbol)
    }

    var displayText: String {
        switch kind {
        case .note: return isSharp ? ".\(value)" : "\(value)"
        case .rest: return ""
        case .tempo: return "♩\(tempoBPM ?? 90)"
        case .symbol:
            let value = symbol ?? ""
            return isSharp ? ".\(value)" : value
        }
    }

    var soundName: String? {
        switch kind {
        case .note: "\(value)"
        case .symbol:
            switch symbol {
            case "+": "+"
            case "−": "-"
            case "×": "mul"
            case "÷": "div"
            case "=": "="
            default: nil
            }
        case .rest, .tempo: nil
        }
    }
}

struct SavedSong: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var tokens: [MusicToken]
    var savedAt = Date()
}

@MainActor
final class SongLibrary: ObservableObject {
    @Published private(set) var songs: [SavedSong] = []

    private let storageKey = "musicalculator.savedSongs.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedSong].self, from: data) else { return }
        songs = decoded
    }

    func save(name: String, tokens: [MusicToken]) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !tokens.isEmpty else { return }
        songs.insert(SavedSong(name: cleanName, tokens: tokens), at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            songs.remove(at: index)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct CalculatorState {
    private(set) var display = "0"
    private var accumulator: Double?
    private var pendingOperation: String?
    private var startsNewNumber = true
    private var showingCalculatedResult = false

    mutating func press(_ key: String) {
        switch key {
        case "0"..."9": enterDigit(key)
        case "00":
            enterDigit("0")
            enterDigit("0")
        case ".": enterDecimal()
        case "+", "−", "×", "÷": setOperation(key)
        case "%": applyPercent()
        case "=": calculate()
        case "⌫": backspace()
        default: break
        }
    }

    private mutating func enterDigit(_ digit: String) {
        if showingCalculatedResult {
            accumulator = nil
            pendingOperation = nil
            showingCalculatedResult = false
        }
        if startsNewNumber || display == "0" {
            display = digit
            startsNewNumber = false
        } else if display.count < 14 {
            display += digit
        }
    }

    private mutating func enterDecimal() {
        if showingCalculatedResult {
            accumulator = nil
            pendingOperation = nil
            showingCalculatedResult = false
        }
        if startsNewNumber {
            display = "0."
            startsNewNumber = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    private mutating func setOperation(_ operation: String) {
        if pendingOperation != nil && !startsNewNumber { calculate() }
        accumulator = Double(display) ?? 0
        pendingOperation = operation
        startsNewNumber = true
        showingCalculatedResult = false
    }

    private mutating func calculate() {
        guard let lhs = accumulator, let operation = pendingOperation else { return }
        let rhs = Double(display) ?? 0
        let result: Double
        switch operation {
        case "+": result = lhs + rhs
        case "−": result = lhs - rhs
        case "×": result = lhs * rhs
        case "÷": result = rhs == 0 ? .nan : lhs / rhs
        default: return
        }
        display = Self.format(result)
        accumulator = nil
        pendingOperation = nil
        startsNewNumber = true
        showingCalculatedResult = true
    }

    private mutating func applyPercent() {
        display = Self.format((Double(display) ?? 0) / 100)
        startsNewNumber = true
    }

    private mutating func backspace() {
        if showingCalculatedResult {
            display = "0"
            accumulator = nil
            pendingOperation = nil
            startsNewNumber = true
            showingCalculatedResult = false
            return
        }
        guard !startsNewNumber else { return }
        display.removeLast()
        if display.isEmpty || display == "-" { display = "0" }
    }

    private static func format(_ number: Double) -> String {
        guard number.isFinite else { return "Error" }
        if number.rounded() == number { return String(format: "%.0f", number) }
        return String(format: "%.8g", number)
    }
}
