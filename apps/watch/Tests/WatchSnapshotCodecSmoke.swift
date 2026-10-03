import Foundation

@main
struct WatchSnapshotCodecSmoke {
  static func main() throws {
    var session = WatchSessionRevision()
    let inFlight = session.value
    precondition(session.accepts(inFlight))
    session.invalidate()
    precondition(!session.accepts(inFlight), "Logout must reject an earlier in-flight response")
    let nextAccount = session.value
    session.invalidate()
    precondition(!session.accepts(nextAccount), "Account changes must reject stale account data")
    precondition(session.accepts(session.value))
    let payload = #"{"displayName":"Athlete","rankings":[{"id":"r1","discipline":"5K","rank":2,"division":"Open","board_type":"OFFICIAL"}],"results":[{"id":"v1","discipline":"5K","mark":"18:01","verified_at":"2026-09-24T12:30:40.123456Z"}],"submissions":[{"id":"s1","discipline":"5K","status":"PENDING_REVIEW","updated_at":"2026-09-24T12:30:40Z"}],"events":[{"id":"e1","name":"Competition","start_at":null,"start_date":"2026-10-24","location":"Calgary"}],"refreshedAt":"2026-09-24T12:30:40.123456789Z"}"#
    let snapshot = try WatchSnapshotCodec.decoder().decode(WatchSnapshot.self, from: Data(payload.utf8))
    precondition(snapshot.rankings.first?.boardType == "OFFICIAL")
    precondition(snapshot.results.first?.mark == "18:01")
    precondition(snapshot.submissions.first?.status == "PENDING_REVIEW")
    precondition(snapshot.events.first?.startAt == nil)
    precondition(snapshot.events.first?.displayDate != nil)
    let dayFormatter = DateFormatter()
    dayFormatter.locale = Locale(identifier: "en_US_POSIX")
    dayFormatter.calendar = Calendar(identifier: .gregorian)
    dayFormatter.dateFormat = "yyyy-MM-dd"
    for zone in ["America/Edmonton", "America/Vancouver", "Pacific/Auckland", "UTC"] {
      dayFormatter.timeZone = TimeZone(identifier: zone)!
      precondition(dayFormatter.string(from: snapshot.events.first!.date(in: dayFormatter.timeZone)!) == "2026-10-24",
                   "A date-only competition must keep its calendar day in \(zone)")
    }
    let cached = try WatchSnapshotCodec.encoder().encode(snapshot)
    let restored = try WatchSnapshotCodec.decoder().decode(WatchSnapshot.self, from: cached)
    precondition(restored.rankings.first?.boardType == "OFFICIAL")
    precondition(restored.results.first?.mark == "18:01")
    precondition(restored.events.first?.displayDate != nil)
    dayFormatter.timeZone = TimeZone(identifier: "America/Edmonton")!
    precondition(dayFormatter.string(from: restored.events.first!.date(in: dayFormatter.timeZone)!) == "2026-10-24",
                 "Cached date-only competitions must preserve their calendar day")
    let instant = Date(timeIntervalSince1970: 1_800_000_000)
    let timed = WatchEvent(id: "timed", name: "Timed event", startAt: instant, startDate: snapshot.events.first!.startDate, location: nil)
    precondition(timed.date(in: dayFormatter.timeZone) == instant, "Timed events must retain their actual instant")
    let undated = WatchEvent(id: "undated", name: "Undated event", startAt: nil, startDate: nil, location: nil)
    precondition(undated.displayDate == nil, "Missing dates must not be invented")
    print("Watch snapshot decoder and session invalidation: PASS")
  }
}
