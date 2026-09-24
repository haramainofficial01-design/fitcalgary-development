import SwiftUI

@main struct FitCalgaryWatchApp: App {
  @StateObject private var store = WatchStore()
  var body: some Scene { WindowGroup { DashboardView().environmentObject(store).tint(FitWatchTheme.coral) } }
}
