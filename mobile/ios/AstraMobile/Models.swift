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

struct WorkoutEquipment: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let name: String
    let description: String?
    let photo: String?
}

struct WorkoutComplexItem: Codable, Identifiable, Hashable {
    let id: Int
    let exerciseId: Int
    let exerciseCode: String?
    let name: String
    let muscleGroup: String?
    let defaultUnit: String?
    let workingWeight: Double?
    let sets: Double?
    let durationMinutes: Double?
    let speedKmh: Double?
}

struct WorkoutComplex: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let comment: String?
    let photos: [String]
    let video: String?
    let items: [WorkoutComplexItem]
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

struct ContentCategory: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let name: String
    let collection: String
    let ownerId: Int?
}

struct ArticleSection: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let articleCount: Int
}

struct ArticleLink: Codable, Hashable {
    let title: String
    let url: String
}

struct Article: Codable, Identifiable, Hashable {
    let id: Int
    let sectionId: Int
    let sectionName: String
    let title: String
    let body: String
    let tags: String?
    let links: [ArticleLink]
    let photos: [String]
    let video: String?
    let isPinned: Bool
    let isHidden: Bool
    let createdAt: String
    let updatedAt: String?
}

struct TrainerInfo: Codable, Hashable {
    let id: Int
    let name: String
    let email: String
}

struct SharedChatItem: Codable, Hashable {
    let type: String
    let id: Int
    let name: String
}

struct TrainerChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let senderId: Int?
    let senderName: String
    let message: String
    let sharedItem: SharedChatItem?
    let createdAt: String
}

struct TrainerChatResponse: Codable {
    let trainer: TrainerInfo?
    var messages: [TrainerChatMessage]
    let unreadCount: Int
}

struct TrainerChatPayload: Encodable {
    let message: String
}

struct ClientNextWorkout: Codable, Hashable {
    let id: Int
    let scheduledAt: String
    let status: String
}

struct ClientSummary: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let email: String
    let nextWorkout: ClientNextWorkout?
    let unreadMessages: Int
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
