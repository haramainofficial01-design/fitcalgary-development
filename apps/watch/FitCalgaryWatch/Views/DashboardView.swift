import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var store: WatchStore
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          Text("FITCALGARY INDEX").font(.caption2.weight(.black)).tracking(1.2).foregroundStyle(.orange)
          Text(store.snapshot.displayName).font(.title2.bold()).lineLimit(1)
          if let best = store.snapshot.rankings.first { GlassCard { HStack { VStack(alignment: .leading) { Text(best.discipline).font(.caption.bold()); Text(best.division).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text("#\(best.rank)").font(.title.bold()).foregroundStyle(.orange) } } }
          else { GlassCard { Label("No verified placement yet", systemImage: "chart.bar").font(.caption) } }
          NavigationLink("Recent results", destination: ResultsView()).buttonStyle(.bordered)
          NavigationLink("Submissions", destination: SubmissionsView()).buttonStyle(.bordered)
          NavigationLink("Upcoming", destination: EventsView()).buttonStyle(.bordered)
          if let message = store.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
        }.padding(.horizontal, 4)
      }.navigationTitle("Index").refreshable { await store.refresh() }.task { if store.snapshot.refreshedAt == .distantPast { await store.refresh() } }
    }
  }
}

struct ResultsView: View { @EnvironmentObject private var store: WatchStore; var body: some View { List { if store.snapshot.results.isEmpty { Text("No verified results yet.").foregroundStyle(.secondary) } else { ForEach(store.snapshot.results) { item in VStack(alignment: .leading) { Text(item.discipline).font(.headline); Text(item.mark).foregroundStyle(.orange); Text(item.verifiedAt, style: .date).font(.caption2).foregroundStyle(.secondary) } } } }.navigationTitle("Results") } }
struct SubmissionsView: View { @EnvironmentObject private var store: WatchStore; var body: some View { List { if store.snapshot.submissions.isEmpty { Text("No active submissions.").foregroundStyle(.secondary) } else { ForEach(store.snapshot.submissions) { item in VStack(alignment: .leading) { Text(item.discipline); Text(item.status.replacingOccurrences(of: "_", with: " ")).font(.caption).foregroundStyle(item.status == "APPROVED" ? .green : item.status == "REJECTED" ? .red : .orange) } } } }.navigationTitle("Reviews") } }
struct EventsView: View { @EnvironmentObject private var store: WatchStore; var body: some View { List { if store.snapshot.events.isEmpty { Text("No published upcoming events.").foregroundStyle(.secondary) } else { ForEach(store.snapshot.events) { item in VStack(alignment: .leading) { Text(item.name); Text(item.startAt, style: .date).font(.caption).foregroundStyle(.orange); if let location = item.location { Text(location).font(.caption2).foregroundStyle(.secondary) } } } } }.navigationTitle("Upcoming") } }
