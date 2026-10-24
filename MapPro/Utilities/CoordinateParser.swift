import Foundation
import CoreLocation

/// Parses coordinates typed into the search field or pasted from a map link.
enum CoordinateParser {
    private static let pairPattern = try! NSRegularExpression(
        pattern: #"^\s*([+-]?\d{1,3}(?:\.\d+)?)\s*°?\s*([NnSs])?\s*(?:,\s*|\s+)([+-]?\d{1,3}(?:\.\d+)?)\s*°?\s*([EeWw])?\s*$"#
    )

    private static let googlePathPattern = try! NSRegularExpression(
        pattern: #"@(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)"#
    )

    /// Supports `37.7749, -122.4194`, `37.7749° N, 122.4194° W`,
    /// `geo:37.7749,-122.4194`, and common Google/Apple Maps links.
    static func parse(_ input: String) -> CLLocationCoordinate2D? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("://"), let url = URL(string: trimmed), let coordinate = parseURL(url) {
            return coordinate
        }

        var candidate = trimmed
        if candidate.lowercased().hasPrefix("geo:") {
            candidate = String(candidate.dropFirst(4))
        }
        return parsePair(candidate)
    }

    static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    static func matches(_ input: String) -> Bool {
        parse(input) != nil
    }

    // MARK: - Private

    private static func parseURL(_ url: URL) -> CLLocationCoordinate2D? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let names: Set<String> = ["ll", "q", "query", "daddr", "saddr", "destination", "center"]
            for item in components.queryItems ?? [] {
                guard names.contains(item.name.lowercased()), let value = item.value else { continue }
                if let coordinate = parsePair(value) {
                    return coordinate
                }
            }
        }

        let path = url.path
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = googlePathPattern.firstMatch(in: path, range: range) else { return nil }
        return coordinate(from: match, latitudeGroup: 1, longitudeGroup: 2, in: path)
    }

    private static func parsePair(_ text: String) -> CLLocationCoordinate2D? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = pairPattern.firstMatch(in: trimmed, range: range) else { return nil }

        // Avoid treating ordinary numeric searches such as "2 3" as coordinates.
        let hasHemisphere = capture(from: match, group: 2, in: trimmed) != nil
            || capture(from: match, group: 4, in: trimmed) != nil
        guard trimmed.contains(".") || hasHemisphere else { return nil }

        guard var latitude = value(from: match, group: 1, in: trimmed),
              var longitude = value(from: match, group: 3, in: trimmed) else { return nil }

        if let hemisphere = capture(from: match, group: 2, in: trimmed)?.uppercased() {
            if hemisphere == "S" { latitude = -abs(latitude) }
            if hemisphere == "N" { latitude = abs(latitude) }
        }
        if let hemisphere = capture(from: match, group: 4, in: trimmed)?.uppercased() {
            if hemisphere == "W" { longitude = -abs(longitude) }
            if hemisphere == "E" { longitude = abs(longitude) }
        }

        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func coordinate(
        from match: NSTextCheckingResult,
        latitudeGroup: Int,
        longitudeGroup: Int,
        in text: String
    ) -> CLLocationCoordinate2D? {
        guard let latitude = value(from: match, group: latitudeGroup, in: text),
              let longitude = value(from: match, group: longitudeGroup, in: text),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func value(from match: NSTextCheckingResult, group: Int, in text: String) -> Double? {
        self.capture(from: match, group: group, in: text).flatMap(Double.init)
    }

    private static func capture(from match: NSTextCheckingResult, group: Int, in text: String) -> String? {
        let range = match.range(at: group)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        let value = String(text[swiftRange]).trimmingCharacters(in: CharacterSet(charactersIn: " °"))
        return value.isEmpty ? nil : value
    }
}
