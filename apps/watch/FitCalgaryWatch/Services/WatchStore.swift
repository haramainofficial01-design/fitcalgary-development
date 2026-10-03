import Foundation
import SwiftUI
@preconcurrency import WatchConnectivity

@MainActor
final class WatchStore: NSObject, ObservableObject {
  @Published private(set) var snapshot = WatchSnapshot.empty
  @Published private(set) var isLoading = false
  @Published private(set) var message: String?
  var isConnected: Bool { KeychainStore.read(account: "accessToken") != nil }
  private let decoder = WatchSnapshotCodec.decoder()
  private let encoder = WatchSnapshotCodec.encoder()
  private var sessionRevision = WatchSessionRevision()
  override init() { super.init(); restore(); if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() } }
  @MainActor func refresh() async {
    guard let token = KeychainStore.read(account: "accessToken"), let base = KeychainStore.read(account: "apiURL"), let url = URL(string: "\(base)/watch/summary") else { message = "Open FitCalgary on iPhone to connect your account."; return }
    guard !isLoading else { return }
    let revision = sessionRevision.value
    isLoading = true
    defer { if sessionRevision.accepts(revision) { isLoading = false } }
    var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.timeoutInterval = 15
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard sessionRevision.accepts(revision) else { return }
      guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
      if http.statusCode == 401 { throw URLError(.userAuthenticationRequired) }
      guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
      let value = try decoder.decode(WatchSnapshot.self, from: data)
      snapshot = value
      UserDefaults.standard.set(try encoder.encode(value), forKey: "snapshot")
      message = nil
    } catch {
      guard sessionRevision.accepts(revision) else { return }
      switch (error as? URLError)?.code {
      case .notConnectedToInternet, .networkConnectionLost, .timedOut:
        message = snapshot.refreshedAt == .distantPast
          ? "No connection. Try again when you’re online."
          : "Offline — showing your last update."
      case .userAuthenticationRequired:
        message = "Sign in again on iPhone to reconnect."
      default:
        message = "Couldn’t refresh right now."
      }
    }
  }
  private func restore() {
    guard KeychainStore.read(account: "accessToken") != nil else {
      UserDefaults.standard.removeObject(forKey: "snapshot")
      return
    }
    guard let data = UserDefaults.standard.data(forKey: "snapshot"),
          let value = try? decoder.decode(WatchSnapshot.self, from: data) else { return }
    snapshot = value
  }
  private func accept(token: String?, apiURL: String?, logout: Bool) {
    // Logout takes precedence even if a stale message contains credentials.
    if logout {
      sessionRevision.invalidate()
      isLoading = false
      KeychainStore.clear()
      UserDefaults.standard.removeObject(forKey: "snapshot")
      snapshot = .empty
      message = "Signed out on iPhone."
    } else if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let apiURL, let url = URL(string: apiURL), url.scheme == "https", url.host != nil {
      sessionRevision.invalidate()
      isLoading = false
      if token != KeychainStore.read(account: "accessToken") || apiURL != KeychainStore.read(account: "apiURL") {
        UserDefaults.standard.removeObject(forKey: "snapshot")
        snapshot = .empty
        message = nil
      }
      KeychainStore.save(token, account: "accessToken")
      KeychainStore.save(apiURL, account: "apiURL")
      Task { await refresh() }
    }
  }

  nonisolated private func receive(_ context: [String: Any]) {
    let token = context["accessToken"] as? String
    let apiURL = context["apiURL"] as? String
    let logout = context["logout"] as? Bool == true
    Task { @MainActor [weak self] in
      self?.accept(token: token, apiURL: apiURL, logout: logout)
    }
  }
}

extension WatchStore: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if activationState == .activated {
      receive(session.receivedApplicationContext)
    }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    receive(applicationContext)
  }
}
