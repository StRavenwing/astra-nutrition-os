import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    let api = APIClient()
    @Published private(set) var user: AuthUser?
    @Published private(set) var isRestoring = true
    @Published var error: String?

    var isAuthenticated: Bool { user != nil }

    func restore() async {
        guard api.token != nil else {
            isRestoring = false
            return
        }
        do { user = try await api.me() }
        catch { api.token = nil }
        isRestoring = false
    }

    func signIn(email: String, password: String, register: Bool = false) async -> Bool {
        error = nil
        do {
            let response = register
                ? try await api.register(email: email, password: password)
                : try await api.login(email: email, password: password)
            api.token = response.accessToken
            user = response.user
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        await api.logout()
        api.token = nil
        user = nil
    }
}
