import SwiftUI

enum FitWatchTheme {
  static let coral = Color(red: 0.78, green: 0.35, blue: 0.29)
}

struct DashboardView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text("FITCALGARY INDEX")
              .font(.caption2.weight(.black))
              .tracking(1.1)
              .foregroundStyle(FitWatchTheme.coral)
            Text(store.isConnected ? store.snapshot.displayName : "Welcome")
              .font(.title3.bold())
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
          .accessibilityElement(children: .combine)

          if !store.isConnected {
            GlassCard {
              VStack(alignment: .leading, spacing: 6) {
                Label("Connect your account", systemImage: "iphone")
                  .font(.caption.weight(.semibold))
                Text("Sign in on iPhone to see your results here.")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          } else if let best = store.snapshot.rankings.first {
            NavigationLink(destination: RankingsView()) {
              GlassCard {
                HStack(alignment: .center, spacing: 8) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT RANK")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(.secondary)
                    Text(best.discipline)
                      .font(.headline)
                      .lineLimit(1)
                    Text(best.division)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                  Spacer(minLength: 4)
                  Text("#\(best.rank)")
                    .font(.title.bold())
                    .foregroundStyle(FitWatchTheme.coral)
                }
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current rank \(best.rank), \(best.discipline), \(best.division)")
          } else {
            GlassCard {
              VStack(alignment: .leading, spacing: 5) {
                Label("No verified placement yet", systemImage: "chart.bar")
                  .font(.caption.weight(.semibold))
                Text("Approved results will appear here.")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }

          if store.isLoading {
            HStack(spacing: 7) {
              ProgressView()
              Text("Updating…").font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Updating FitCalgary")
          }

          if store.isConnected {
            NavigationLink(destination: ResultsView()) {
              HomeLink(title: "My results", detail: resultSummary, icon: "checkmark.seal")
            }
            NavigationLink(destination: RankingsView()) {
              HomeLink(title: "Rankings", detail: rankingSummary, icon: "chart.bar.xaxis")
            }
            NavigationLink(destination: SubmissionsView()) {
              HomeLink(title: "Review status", detail: submissionSummary, icon: "clock.badge.checkmark")
            }
            NavigationLink(destination: EventsView()) {
              HomeLink(title: "Upcoming", detail: eventSummary, icon: "calendar")
            }
          }

          if let message = store.message {
            Label(message, systemImage: store.isConnected ? "info.circle" : "iphone")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .accessibilityLabel(message)
          } else if store.snapshot.refreshedAt != .distantPast {
            Text("Updated \(store.snapshot.refreshedAt, style: .relative) ago")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .accessibilityLabel("Last updated \(store.snapshot.refreshedAt.formatted(date: .abbreviated, time: .shortened))")
          }
        }
        .padding(.horizontal, 3)
        .padding(.bottom, 8)
      }
      .navigationTitle("Home")
      .refreshable { await store.refresh() }
      .task {
        if store.snapshot.refreshedAt == .distantPast { await store.refresh() }
      }
    }
  }

  private var resultSummary: String {
    guard let result = store.snapshot.results.first else { return "No verified results" }
    return "\(result.discipline) · \(result.mark)"
  }

  private var rankingSummary: String {
    guard let ranking = store.snapshot.rankings.first else { return "No placement yet" }
    return "#\(ranking.rank) · \(ranking.discipline)"
  }

  private var submissionSummary: String {
    guard let submission = store.snapshot.submissions.first else { return "No active submissions" }
    return submission.status.readableStatus
  }

  private var eventSummary: String {
    guard let event = store.snapshot.events.first else { return "No published events" }
    return event.name
  }
}

private struct HomeLink: View {
  let title: String
  let detail: String
  let icon: String

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .font(.body.weight(.semibold))
        .foregroundStyle(FitWatchTheme.coral)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.headline)
        Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer(minLength: 2)
      Image(systemName: "chevron.right")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
  }
}

struct ResultsView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    List {
      if store.snapshot.results.isEmpty {
        ContentUnavailableView(
          "No verified results",
          systemImage: "checkmark.seal",
          description: Text("Approved results from FitCalgary will appear here.")
        )
      } else {
        ForEach(store.snapshot.results) { item in
          VStack(alignment: .leading, spacing: 3) {
            Text(item.discipline).font(.headline)
            Text(item.mark).font(.title3.bold()).foregroundStyle(FitWatchTheme.coral)
            Label(item.verifiedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark.seal.fill")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .navigationTitle("Results")
  }
}

struct RankingsView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    List {
      if store.snapshot.rankings.isEmpty {
        ContentUnavailableView(
          "No placement yet",
          systemImage: "chart.bar.xaxis",
          description: Text("A placement appears after a result is verified.")
        )
      } else {
        ForEach(store.snapshot.rankings) { item in
          HStack(alignment: .center, spacing: 8) {
            Text("#\(item.rank)")
              .font(.title3.bold())
              .foregroundStyle(FitWatchTheme.coral)
              .frame(minWidth: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.discipline).font(.headline).lineLimit(1)
              Text("\(item.division) · \(item.boardType.readableStatus)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Rank \(item.rank), \(item.discipline), \(item.division)")
        }
      }
    }
    .navigationTitle("Rankings")
  }
}

struct SubmissionsView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    List {
      if store.snapshot.submissions.isEmpty {
        ContentUnavailableView(
          "No active reviews",
          systemImage: "clock.badge.checkmark",
          description: Text("Submit a result from the iPhone app.")
        )
      } else {
        ForEach(store.snapshot.submissions) { item in
          VStack(alignment: .leading, spacing: 4) {
            Text(item.discipline).font(.headline)
            HStack(spacing: 5) {
              Circle().fill(item.status.statusColor).frame(width: 6, height: 6)
              Text(item.status.readableStatus).font(.caption.weight(.semibold))
            }
            Text("Updated \(item.updatedAt, style: .relative) ago")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .navigationTitle("Reviews")
  }
}

struct EventsView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    List {
      if store.snapshot.events.isEmpty {
        ContentUnavailableView(
          "No upcoming events",
          systemImage: "calendar",
          description: Text("Published competitions will appear here.")
        )
      } else {
        ForEach(store.snapshot.events) { item in
          VStack(alignment: .leading, spacing: 3) {
            Text(item.name).font(.headline)
            if let date = item.displayDate {
              Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitWatchTheme.coral)
            } else {
              Text("Date to be confirmed")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            if let location = item.location, !location.isEmpty {
              Label(location, systemImage: "mappin")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .navigationTitle("Upcoming")
  }
}

private extension String {
  var readableStatus: String {
    replacingOccurrences(of: "_", with: " ")
      .lowercased()
      .split(separator: " ")
      .map { $0.capitalized }
      .joined(separator: " ")
  }

  var statusColor: Color {
    switch uppercased() {
    case "APPROVED": return .green
    case "REJECTED": return .red
    default: return FitWatchTheme.coral
    }
  }
}
