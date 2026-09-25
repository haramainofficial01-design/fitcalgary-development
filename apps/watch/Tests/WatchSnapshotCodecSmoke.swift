import Foundation

@main
struct WatchSnapshotCodecSmoke {
  static func main() throws {
    let payload = #"{"displayName":"Athlete","rankings":[{"id":"r1","discipline":"5K","rank":2,"division":"Open","board_type":"OFFICIAL"}],"results":[{"id":"v1","discipline":"5K","mark":"18:01","verified_at":"2026-09-24T12:30:40.123456Z"}],"submissions":[{"id":"s1","discipline":"5K","status":"PENDING_REVIEW","updated_at":"2026-09-24T12:30:40Z"}],"events":[{"id":"e1","name":"Competition","start_at":null,"start_date":"2026-10-24","location":"Calgary"}],"refreshedAt":"2026-09-24T12:30:40.123456789Z"}"#
    let snapshot = try WatchSnapshotCodec.decoder().decode(WatchSnapshot.self, from: Data(payload.utf8))
    precondition(snapshot.rankings.first?.boardType == "OFFICIAL")
    precondition(snapshot.results.first?.mark == "18:01")
    precondition(snapshot.submissions.first?.status == "PENDING_REVIEW")
    precondition(snapshot.events.first?.startAt == nil)
    precondition(snapshot.events.first?.displayDate != nil)
    let cached = try WatchSnapshotCodec.encoder().encode(snapshot)
    let restored = try WatchSnapshotCodec.decoder().decode(WatchSnapshot.self, from: cached)
    precondition(restored.rankings.first?.boardType == "OFFICIAL")
    precondition(restored.results.first?.mark == "18:01")
    precondition(restored.events.first?.displayDate != nil)
    print("Watch snapshot decoder: PASS")
  }
}
