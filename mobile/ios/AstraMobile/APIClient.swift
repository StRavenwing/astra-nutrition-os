import Foundation
import Security

final class APIClient {
    private let defaults = UserDefaults.standard
    private let baseURLKey = "astra_api_base_url"
    private let tokenKey = "astra_access_token"
    private let defaultBaseURL = "http://204.168.255.69:8787/api/v1"
    private let legacyLocalBaseURLs = [
        "http://127.0.0.1:8787/api/v1",
        "http://10.0.2.2:8787/api/v1"
    ]

    var baseURL: String {
        get {
            let stored = defaults.string(forKey: baseURLKey)
            return stored == nil || legacyLocalBaseURLs.contains(stored ?? "") ? defaultBaseURL : stored!
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")), forKey: baseURLKey) }
    }

    var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: tokenKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: tokenKey
            ]
            SecItemDelete(query as CFDictionary)
            if let newValue, let data = newValue.data(using: .utf8) {
                var item = query
                item[kSecValueData as String] = data
                SecItemAdd(item as CFDictionary, nil)
            }
        }
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200..<300).contains(http.statusCode) {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw APIError.server(payload?["error"] as? String ?? "Ошибка запроса (\(http.statusCode))")
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await request("auth/login", method: "POST", body: AuthBody(email: email, password: password))
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        try await request("auth/register", method: "POST", body: AuthBody(email: email, password: password))
    }

    func me() async throws -> AuthUser { try await request("auth/me") }
    func dashboard() async throws -> Dashboard { try await request("dashboard") }
    func products() async throws -> [Product] { try await request("products") }
    func recipes() async throws -> [Recipe] { try await request("recipes") }
    func recipe(id: Int) async throws -> RecipeDetail { try await request("recipes/\(id)") }
    func diary() async throws -> [DiaryEntry] { try await request("diary") }
    func progress() async throws -> [ProgressEntry] { try await request("progress") }
    func workouts() async throws -> [WorkoutEntry] { try await request("workouts") }
    func workoutPlans() async throws -> [WorkoutPlan] { try await request("workout-plans") }
    func exercises() async throws -> [Exercise] { try await request("exercises") }
    func workoutEquipment() async throws -> [WorkoutEquipment] { try await request("workout-equipment") }
    func workoutComplexes() async throws -> [WorkoutComplex] { try await request("workout-complexes") }
    func categories(kind: String) async throws -> [ContentCategory] { try await request("categories?kind=\(kind.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kind)") }
    func articleSections() async throws -> [ArticleSection] { try await request("article-sections") }
    func articles() async throws -> [Article] { try await request("articles") }
    func myTrainer() async throws -> TrainerInfoResponse { try await request("clients/me/trainer") }
    func myTrainerChat() async throws -> TrainerChatResponse { try await request("clients/me/chat") }
    func sendMyTrainerChat(message: String) async throws -> TrainerChatMessage { try await request("clients/me/chat", method: "POST", body: TrainerChatPayload(message: message)) }
    func clients() async throws -> [ClientSummary] { try await request("clients") }
    func clientChat(id: Int) async throws -> [TrainerChatMessage] { try await request("clients/\(id)/chat") }
    func sendClientChat(id: Int, message: String) async throws -> TrainerChatMessage { try await request("clients/\(id)/chat", method: "POST", body: TrainerChatPayload(message: message)) }
    func createDiary(_ payload: DiaryPayload) async throws -> [DiaryEntry] { try await request("diary", method: "POST", body: payload) }
    func deleteDiary(id: Int) async throws -> DeleteResponse { try await request("diary/\(id)", method: "DELETE") }
    func createProgress(_ payload: ProgressPayload) async throws -> ProgressEntry { try await request("progress", method: "POST", body: payload) }
    func createWorkout(_ payload: WorkoutPayload) async throws -> WorkoutEntry { try await request("workouts", method: "POST", body: payload) }
    func completeWorkoutPlan(id: Int) async throws -> WorkoutPlan { try await request("workout-plans/\(id)/complete", method: "POST") }
    func logout() async {
        do { let _: EmptyResponse = try await request("auth/logout", method: "POST") }
        catch { /* JWT is invalidated locally below. */ }
    }
}

private struct AuthBody: Encodable { let email: String; let password: String }
struct DeleteResponse: Decodable { let deleted: Bool; let id: Int }
struct EmptyResponse: Decodable { let ok: Bool }
struct TrainerInfoResponse: Codable { let trainer: TrainerInfo? }

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeClosure = { encoder in try value.encode(to: encoder) } }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}
