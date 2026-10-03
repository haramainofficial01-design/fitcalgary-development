import Foundation

/// Invalidates responses started under an earlier account/session context.
struct WatchSessionRevision {
  private(set) var value: UInt64 = 0
  mutating func invalidate() { value &+= 1 }
  func accepts(_ revision: UInt64) -> Bool { value == revision }
}

struct WatchSnapshot: Codable, Equatable {
  var displayName: String
  var rankings: [WatchRanking]
  var results: [WatchResult]
  var submissions: [WatchSubmission]
  var events: [WatchEvent]
  var refreshedAt: Date
  static let empty = WatchSnapshot(displayName: "Athlete", rankings: [], results: [], submissions: [], events: [], refreshedAt: .distantPast)
}

struct WatchRanking: Codable, Identifiable, Equatable { let id: String; let discipline: String; let rank: Int; let division: String; let boardType: String }
struct WatchResult: Codable, Identifiable, Equatable { let id: String; let discipline: String; let mark: String; let verifiedAt: Date }
struct WatchSubmission: Codable, Identifiable, Equatable { let id: String; let discipline: String; let status: String; let updatedAt: Date }
struct WatchEvent: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let startAt: Date?
  let startDate: Date?
  let location: String?

  var displayDate: Date? { date(in: .current) }

  /// A date-only value represents a calendar day, not a UTC event time.
  /// Preserve that day when SwiftUI formats it in the viewer's time zone.
  func date(in timeZone: TimeZone) -> Date? {
    if let startAt { return startAt }
    guard let startDate else { return nil }
    var source = Calendar(identifier: .gregorian)
    source.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = source.dateComponents([.year, .month, .day], from: startDate)
    var display = Calendar(identifier: .gregorian)
    display.timeZone = timeZone
    return display.date(from: day)
  }
}

enum WatchSnapshotCodec {
  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { input in
      let container = try input.singleValueContainer()
      let raw = try container.decode(String.self)
      for format: ISO8601DateFormatter.Options in [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime],
        [.withFullDate]
      ] {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.formatOptions = format
        if let date = formatter.date(from: raw) { return date }
      }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date in Watch response")
    }
    return decoder
  }

  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }
}
