import Foundation

/// North American English reference pronunciations from CMUdict.
/// IPA labels are a broad, experimental mapping to the phoneme CTC vocabulary.
actor PhoneticDictionaryService {
    static let shared = PhoneticDictionaryService()
    private var entries: [String: [[String]]] = [:]
    private var loaded = false

    struct Pronunciation: Sendable, Equatable {
        let arpabet: [String]
        let phonemes: [String]
        var ipa: String { phonemes.joined() }
    }

    enum DictionaryError: LocalizedError {
        case missingDictionary, invalidDictionary, wordNotFound(String), unsupportedPhone(String)
        var errorDescription: String? {
            switch self {
            case .missingDictionary: return "cmudict.dict is missing from the app bundle."
            case .invalidDictionary: return "The pronunciation dictionary is empty or invalid."
            case .wordNotFound(let word): return "No reference pronunciation found for \(word)."
            case .unsupportedPhone(let phone): return "Unsupported phonetic symbol: \(phone)."
            }
        }
    }

    private static let phones: [String: String] = [
        "AA":"ɑː", "AE":"æ", "AH":"ʌ", "AO":"ɔː", "AW":"aʊ",
        "AY":"aɪ", "B":"b", "CH":"tʃ", "D":"d", "DH":"ð",
        "EH":"ɛ", "ER":"ɚ", "EY":"eɪ", "F":"f", "G":"ɡ",
        "HH":"h", "IH":"ɪ", "IY":"iː", "JH":"dʒ", "K":"k",
        "L":"l", "M":"m", "N":"n", "NG":"ŋ", "OW":"oʊ",
        "OY":"ɔɪ", "P":"p", "R":"ɹ", "S":"s", "SH":"ʃ",
        "T":"t", "TH":"θ", "UH":"ʊ", "UW":"uː", "V":"v",
        "W":"w", "Y":"j", "Z":"z", "ZH":"ʒ"
    ]

    func prepareDictionary() throws {
        guard !loaded else { return }
        guard let url = Bundle.main.url(forResource: "cmudict", withExtension: "txt") else {
            throw DictionaryError.missingDictionary
        }
        try load(from: url)
    }

    /// Also allows testing with a dictionary outside the app bundle.
    func load(from url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        var parsed: [String: [[String]]] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let clean = line.prefix(while: { $0 != "#" })
            let fields = clean.split(whereSeparator: \.isWhitespace)
            guard fields.count > 1, !fields[0].hasPrefix(";;;") else { continue }
            let key = String(fields[0]).replacingOccurrences(of: #"\([0-9]+\)$"#, with: "", options: .regularExpression).lowercased()
            let symbols = fields.dropFirst().map(String.init)
            parsed[key, default: []].append(symbols)
        }
        guard !parsed.isEmpty else { throw DictionaryError.invalidDictionary }
        entries = parsed
        loaded = true
    }

    func pronunciations(for word: String) throws -> [Pronunciation] {
        try prepareDictionary()
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'").lowercased()
        guard let variants = entries[key] else { throw DictionaryError.wordNotFound(word) }
        return try variants.map { symbols in
            Pronunciation(arpabet: symbols, phonemes: try Self.convert(symbols))
        }
    }

    /// Keeps stress in ARPAbet, but does not claim to score stress from CTC labels.
    static func convert(_ symbols: [String]) throws -> [String] {
        var result: [String] = []
        for symbol in symbols {
            let base = String(symbol.prefix(while: { !$0.isNumber }))
            if symbol == "AH0" { result.append("ə"); continue }
            guard let label = phones[base] else { throw DictionaryError.unsupportedPhone(symbol) }
            result.append(label)
        }
        return result
    }
}
