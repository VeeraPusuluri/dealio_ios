import Foundation
import Compression

/// Reads a CSV or XLSX file into rows of cells.
///
/// XLSX is parsed directly rather than with a spreadsheet library: an .xlsx is a
/// zip of XML, and `XMLParser` plus `Compression` are both already on the
/// platform, so the whole reader costs nothing at build time. Mirrors Android's
/// `data/Spreadsheet.kt`, which avoids Apache POI for the same reason.
enum Spreadsheet {

    /// True when the name looks like a workbook rather than a delimited text file.
    static func isWorkbook(_ fileName: String) -> Bool {
        fileName.lowercased().hasSuffix(".xlsx")
    }

    static func read(_ data: Data, fileName: String) -> [[String]] {
        if isWorkbook(fileName) { return readXLSX(data) }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        return readDelimited(text)
    }

    // MARK: - CSV

    /// RFC-4180-ish: honours quoted fields so an address containing a comma
    /// ("Gachibowli, Hyderabad") stays one cell, and `""` as an escaped quote.
    /// Tab-separated files are handled too — Excel's "Unicode text" export.
    static func readDelimited(_ text: String) -> [[String]] {
        // Excel writes a BOM.
        var body = Substring(text)
        if body.hasPrefix("\u{FEFF}") { body = body.dropFirst() }

        let firstLine = body.prefix { !$0.isNewline }
        let delimiter: Character = firstLine.filter { $0 == "\t" }.count > firstLine.filter { $0 == "," }.count
            ? "\t" : ","

        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var quoted = false

        func endCell() {
            row.append(cell.trimmingCharacters(in: .whitespaces))
            cell = ""
        }
        func endRow() {
            endCell()
            if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
            row = []
        }

        var index = body.startIndex
        while index < body.endIndex {
            let character = body[index]
            let next = body.index(after: index)
            if quoted, character == "\"", next < body.endIndex, body[next] == "\"" {
                cell.append("\"")
                index = next
            } else if character == "\"" {
                quoted.toggle()
            } else if !quoted, character == delimiter {
                endCell()
            } else if !quoted, character == "\n" {
                endRow()
            } else if !quoted, character == "\r" {
                // Part of a CRLF; the \n does the work.
            } else {
                cell.append(character)
            }
            index = body.index(after: index)
        }
        endRow()
        return rows
    }

    // MARK: - XLSX

    private static func readXLSX(_ data: Data) -> [[String]] {
        let entries = Zip.entries(in: data)
        let shared = entries.first { $0.name == "xl/sharedStrings.xml" }
            .flatMap { Zip.contents(of: $0, in: data) }
            .map(parseSharedStrings) ?? []
        // The first worksheet; workbook.xml order isn't needed for a
        // single-sheet export, which is what people actually upload.
        guard let sheetEntry = entries
            .filter({ $0.name.hasPrefix("xl/worksheets/sheet") && $0.name.hasSuffix(".xml") })
            .min(by: { $0.name < $1.name }),
              let sheet = Zip.contents(of: sheetEntry, in: data) else { return [] }
        return parseSheet(sheet, shared: shared)
    }

    /// `<si><t>Rahul</t></si>` — concatenating the `t` runs handles rich text.
    private static func parseSharedStrings(_ xml: Data) -> [String] {
        let handler = SharedStringsHandler()
        let parser = XMLParser(data: xml)
        parser.delegate = handler
        parser.parse()
        return handler.strings
    }

    private static func parseSheet(_ xml: Data, shared: [String]) -> [[String]] {
        let handler = SheetHandler(shared: shared)
        let parser = XMLParser(data: xml)
        parser.delegate = handler
        parser.parse()
        return handler.rows
    }

    /// "BC12" → 54. Letters are base-26, 1-indexed; the result is 0-indexed.
    static func columnIndex(_ reference: String) -> Int {
        var n = 0
        for character in reference {
            guard character.isLetter, let ascii = character.uppercased().unicodeScalars.first else { break }
            n = n * 26 + Int(ascii.value - 64)
        }
        return max(n - 1, 0)
    }
}

// MARK: - XML handlers

private final class SharedStringsHandler: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var text = ""
    private var inItem = false
    private var inText = false

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        switch element {
        case "si": inItem = true; text = ""
        case "t": inText = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem, inText { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch element {
        case "t": inText = false
        case "si": strings.append(text); inItem = false
        default: break
        }
    }
}

private final class SheetHandler: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    private let shared: [String]
    private var row: [String] = []
    private var value = ""
    private var cellType = ""
    private var cellColumn = 0
    private var inValue = false

    init(shared: [String]) { self.shared = shared }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        switch element {
        case "row": row = []
        case "c":
            cellType = attributes["t"] ?? ""
            cellColumn = Spreadsheet.columnIndex(attributes["r"] ?? "")
            value = ""
        // `v` for normal cells, `t` for the inline-string form.
        case "v", "t": inValue = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch element {
        case "v", "t":
            inValue = false
        case "c":
            // Blank cells are simply absent from the XML, so pad to the cell's
            // real column or every later value shifts left.
            while row.count < cellColumn { row.append("") }
            if cellType == "s", let index = Int(value), shared.indices.contains(index) {
                row.append(shared[index])
            } else {
                row.append(value)
            }
        case "row":
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                rows.append(row)
            }
        default: break
        }
    }
}

// MARK: - Minimal zip reader

/// Just enough of the ZIP format to pull two named files out of an .xlsx.
///
/// Reads the central directory rather than streaming, because the two entries
/// that matter are known by name and scanning for them is cheaper than
/// inflating everything on the way past.
enum Zip {
    struct Entry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4b50
    private static let centralFileHeaderSignature: UInt32 = 0x0201_4b50

    static func entries(in data: Data) -> [Entry] {
        guard let eocd = findEndOfCentralDirectory(data) else { return [] }
        let count = Int(read16(data, eocd + 10))
        var offset = Int(read32(data, eocd + 16))
        var result: [Entry] = []
        for _ in 0..<count {
            guard offset + 46 <= data.count, read32(data, offset) == centralFileHeaderSignature else { break }
            let method = read16(data, offset + 10)
            let compressed = Int(read32(data, offset + 20))
            let uncompressed = Int(read32(data, offset + 24))
            let nameLength = Int(read16(data, offset + 28))
            let extraLength = Int(read16(data, offset + 30))
            let commentLength = Int(read16(data, offset + 32))
            let localOffset = Int(read32(data, offset + 42))
            let nameStart = offset + 46
            guard nameStart + nameLength <= data.count else { break }
            let name = String(decoding: data[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            result.append(Entry(name: name, compressionMethod: method,
                                compressedSize: compressed, uncompressedSize: uncompressed,
                                localHeaderOffset: localOffset))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        return result
    }

    static func contents(of entry: Entry, in data: Data) -> Data? {
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count else { return nil }
        // The local header repeats the name and extra lengths, and they can
        // differ from the central directory's — the data starts after *these*.
        let nameLength = Int(read16(data, header + 26))
        let extraLength = Int(read16(data, header + 28))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start <= end, end <= data.count else { return nil }
        let payload = data[start..<end]

        switch entry.compressionMethod {
        case 0: return Data(payload)
        case 8: return inflate(Data(payload), expected: entry.uncompressedSize)
        default: return nil
        }
    }

    /// Raw DEFLATE — Apple's `COMPRESSION_ZLIB` is the unwrapped stream, which is
    /// exactly what a zip entry holds.
    private static func inflate(_ data: Data, expected: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        // A little headroom over the stated size: a corrupt header should not
        // silently truncate, and the extra byte tells us it overran.
        let capacity = max(expected, data.count * 4) + 1
        var output = Data(count: capacity)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            data.withUnsafeBytes { source -> Int in
                guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(destinationBase, capacity,
                                                 sourceBase, data.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return output.prefix(written)
    }

    /// The EOCD is at the end, after a comment of up to 64K. Scan backwards.
    private static func findEndOfCentralDirectory(_ data: Data) -> Int? {
        let minimum = 22
        guard data.count >= minimum else { return nil }
        let lowest = max(0, data.count - minimum - 65_535)
        var offset = data.count - minimum
        while offset >= lowest {
            if read32(data, offset) == endOfCentralDirectorySignature { return offset }
            offset -= 1
        }
        return nil
    }

    private static func read16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt32(data[base]) | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16) | (UInt32(data[base + 3]) << 24)
    }
}
