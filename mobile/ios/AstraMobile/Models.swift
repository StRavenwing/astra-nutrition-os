import Foundation

struct AuthUser: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String
    let isAdmin: Bool
    let isTrainer: Bool
}

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: AuthUser
}

struct Dashboard: Codable {
    let products: Int
    let recipes: Int
    let approved: Int
    let latest: ProgressEntry?
    let top: [Recipe]
}

struct Product: Codable, Identifiable, Hashable {
    let id: Int
    let code: String
    let name: String
    let category: String?
    let unit: String?
    let kcal: Double?
    let proteinG: Double?
    let fatG: Double?
    let carbsG: Double?
}

struct Recipe: Codable, Identifiable, Hashable {
    let id: Int
    let code: String
    let name: String
    let category: String
    let subcategory: String?
    let status: String?
    let servings: Double?
    let kcalPerServing: Double?
    let proteinPerServingG: Double?
    let fatPerServingG: Double?
    let carbsPerServingG: Double?
    let costPerServingRsd: Double?
}

struct RecipeIngredient: Codable, Identifiable, Hashable {
    let id: Int
    let productId: Int
    let name: String
    let quantity: Double?
    let unit: String?
}

struct RecipeDetail: Codable {
    let recipe: Recipe
    let ingredients: [RecipeIngredient]
}

struct DiaryEntry: Codable, Identifiable, Hashable {
    let id: Int
    let entryDate: String
    let mealType: String?
    let recipeId: Int?
    let productId: Int?
    let servings: Double?
    let quantity: Double?
    let unit: String?
    let measurementName: String?
    let measurementQuantity: Double?
    let comment: String?
    let name: String?
    let itemType: String
    let kcalPerServing: Double?
    let proteinPerServingG: Double?
    let fatPerServingG: Double?
    let carbsPerServingG: Double?
}

struct ProgressEntry: Codable, Identifiable, Hashable {
    let id: Int
    let measuredAt: String
    let weightKg: Double?
    let desiredWeightKg: Double?
    let heightCm: Double?
    let bmi: Double?
    let bodyFatPct: Double?
    let muscleMassKg: Double?
    let kcalTarget: Double?
    let proteinTargetG: Double?
    let fatTargetG: Double?
    let carbsTargetG: Double?
    let waistCm: Double?
    let chestCm: Double?
    let hipsCm: Double?
    let sleepScore: Double?
    let wellbeingScore: Double?
    let comment: String?
}

struct WorkoutPlanItem: Codable, Identifiable, Hashable {
    let id: Int?
    let exerciseId: Int
    let name: String?
    let muscleGroup: String?
    let workingWeight: Double?
    let sets: Double?
    let durationMinutes: Double?
    let speedKmh: Double?
}

struct WorkoutPlan: Codable, Identifiable, Hashable {
    let id: Int
    let scheduledAt: String
    let durationMinutes: Double?
    let status: String
    let completedAt: String?
    let items: [WorkoutPlanItem]
}

struct WorkoutEntry: Codable, Identifiable, Hashable {
    let id: Int
    let performedAt: String
    let exerciseId: Int
    let name: String
    let muscleGroup: String?
    let workingWeight: Double?
    let sets: Double?
    let reps: Double?
    let rir: String?
    let comment: String?
}

struct Exercise: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let muscleGroup: String?
    let defaultUnit: String?
    let defaultSets: Double?
    let defaultReps: Double?
}

struct RecipePayload: Encodable {
    let recipeId: Int?
    let productId: Int?
    let mealType: String
    let servings: Double?
    let quantity: Double?
    let measurementName: String?
}

struct DiaryPayload: Encodable {
    let entryDate: String
    let items: [RecipePayload]
}

struct ProgressPayload: Encodable {
    let measuredAt: String
    let weightKg: Double?
    let desiredWeightKg: Double?
    let heightCm: Double?
    let waistCm: Double?
    let wellbeingScore: Double?
    let comment: String?
}

struct WorkoutPayload: Encodable {
    let performedAt: String
    let exerciseId: Int
    let workingWeight: Double?
    let sets: Double?
    let reps: Double?
    let rir: String?
    let comment: String?
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Некорректный адрес API"
        case .invalidResponse: return "Сервер вернул некорректный ответ"
        case .server(let message): return message
        case .decoding(let message): return "Ошибка данных: \(message)"
        }
    }
}
