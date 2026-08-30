import Foundation
import SwiftUI
@preconcurrency import WatchConnectivity

@MainActor
final class WatchStore: NSObject, ObservableObject {
  @Published private(set) var snapshot = WatchSnapshot.empty
  @Published private(set) var isLoading = false
  @Published private(set) var message: String?
  private let decoder: JSONDecoder = { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }()
  private let encoder: JSONEncoder = { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }()
  override init() { super.init(); restore(); if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() } }
  @MainActor func refresh() async {
    guard let token = KeychainStore.read(account: "accessToken"), let base = KeychainStore.read(account: "apiURL"), let url = URL(string: "\(base)/watch/summary") else { message = "Open FitCalgary on iPhone to connect your account."; return }
    isLoading = true; defer { isLoading = false }
    var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.timeoutInterval = 15
    do { let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }; let value = try decoder.decode(WatchSnapshot.self, from: data); snapshot = value; UserDefaults.standard.set(try encoder.encode(value), forKey: "snapshot"); message = nil }
    catch { message = (error as? URLError)?.code == .notConnectedToInternet ? "Offline — showing your last update." : "Couldn’t refresh. Open the iPhone app if sign-in expired." }
  }
  private func restore() { guard let data = UserDefaults.standard.data(forKey: "snapshot"), let value = try? decoder.decode(WatchSnapshot.self, from: data) else { return }; snapshot = value }
  private func accept(token: String?, apiURL: String?, logout: Bool) {
    if let token, let apiURL {
      KeychainStore.save(token, account: "accessToken")
      KeychainStore.save(apiURL, account: "apiURL")
      Task { await refresh() }
    } else if logout {
      KeychainStore.clear()
      UserDefaults.standard.removeObject(forKey: "snapshot")
      snapshot = .empty
      message = "Signed out on iPhone."
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
