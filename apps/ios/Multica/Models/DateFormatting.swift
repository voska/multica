import Foundation

enum MulticaDate {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFractional = Date.ISO8601FormatStyle().year().month().day()
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
        if let date = try? withFractional.parse(raw) { return date }
        let plain = Date.ISO8601FormatStyle()
        if let date = try? plain.parse(raw) { return date }
        return nil
    }

    static func relative(_ raw: String?) -> String? {
        guard let date = parse(raw) else { return nil }
        return date.formatted(.relative(presentation: .numeric))
    }

    static func absolute(_ raw: String?, style: Date.FormatStyle = .dateTime.day().month().year().hour().minute()) -> String? {
        guard let date = parse(raw) else { return nil }
        return date.formatted(style)
    }

    static func mediumDate(_ raw: String?) -> String? {
        guard let date = parse(raw) else { return nil }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
