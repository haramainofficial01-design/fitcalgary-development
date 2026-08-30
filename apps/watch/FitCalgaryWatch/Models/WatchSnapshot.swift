import Foundation

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
struct WatchEvent: Codable, Identifiable, Equatable { let id: String; let name: String; let startAt: Date; let location: String? }
