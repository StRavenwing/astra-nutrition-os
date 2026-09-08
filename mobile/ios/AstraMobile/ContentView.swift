import SwiftUI

enum AppTab: Hashable { case overview, diary, products, recipes, progress, workouts, trainer, information, catalog, settings }

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @AppStorage("astra_theme") private var theme = "light"

    var body: some View {
        Group {
            if session.isRestoring { ProgressView("Загрузка Astra…") }
            else if session.isAuthenticated { MobileMainView() }
            else { AuthView() }
        }
        .tint(AstraTheme.blue)
        .preferredColorScheme(theme == "dark" ? .dark : .light)
    }
}

struct AuthView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var isRegister = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [AstraTheme.canvas, Color(red: 0.91, green: 0.95, blue: 1), Color(red: 0.91, green: 0.98, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.circle.fill").font(.system(size: 42)).foregroundStyle(AstraTheme.green)
                    VStack(alignment: .leading) {
                        Text("Astra Nutrition OS").font(.title2.weight(.bold))
                        Text("PERSONAL WORKSPACE").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.muted)
                    }
                }
                Picker("Режим", selection: $isRegister) {
                    Text("Вход").tag(false)
                    Text("Регистрация").tag(true)
                }.pickerStyle(.segmented)
                VStack(spacing: 14) {
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    SecureField("Пароль", text: $password).textFieldStyle(.roundedBorder)
                    if let error = session.error { Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
                    Button {
                        isLoading = true
                        Task { _ = await session.signIn(email: email, password: password, register: isRegister); isLoading = false }
                    } label: {
                        HStack { Spacer(); if isLoading { ProgressView().tint(.white) }; Text(isRegister ? "Создать аккаунт" : "Войти").fontWeight(.bold); Spacer() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.count < 8)
                }
            }
            .padding(22)
            .background(AstraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
            .shadow(color: AstraTheme.ink.opacity(0.08), radius: 24, y: 10)
            .padding(22)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var tab: AppTab = .overview

    var body: some View {
        TabView(selection: $tab) {
            DashboardView().tabItem { Label("Обзор", systemImage: "square.grid.2x2.fill") }.tag(AppTab.overview)
            DiaryView().tabItem { Label("Дневник", systemImage: "fork.knife") }.tag(AppTab.diary)
            ProductsView().tabItem { Label("Продукты", systemImage: "carrot.fill") }.tag(AppTab.products)
            RecipesView().tabItem { Label("Рецепты", systemImage: "book.closed.fill") }.tag(AppTab.recipes)
            ProgressScreen().tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }.tag(AppTab.progress)
            WorkoutsView().tabItem { Label("Тренировки", systemImage: "bolt.fill") }.tag(AppTab.workouts)
            MoreView(tab: $tab).tabItem { Label("Ещё", systemImage: "ellipsis.circle.fill") }.tag(AppTab.settings)
        }
        .background(AstraTheme.canvas)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var session: SessionStore
    let onNavigate: (AppTab) -> Void = { _ in }
    @State private var dashboard: Dashboard?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Header(title: "Обзор", subtitle: "Твоя система питания и движения")
                    if let dashboard {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricTile(label: "Продукты", value: "\(dashboard.products)", tint: AstraTheme.blue)
                            MetricTile(label: "Рецепты", value: "\(dashboard.recipes)", tint: AstraTheme.green)
                            MetricTile(label: "Одобрено", value: "\(dashboard.approved)", tint: .orange)
                            MetricTile(label: "Вес", value: dashboard.latest?.weightKg.display ?? "—", tint: .purple)
                        }
                        if let latest = dashboard.latest {
                            AstraCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Последний замер").font(.headline)
                                    HStack { Label(latest.measuredAt, systemImage: "calendar"); Spacer(); Text("\(latest.weightKg.display) кг").font(.title3.weight(.bold)) }
                                        .foregroundStyle(AstraTheme.muted)
                                    HStack(spacing: 12) {
                                        MetricTile(label: "Талия", value: "\(latest.waistCm.display) см", tint: AstraTheme.green)
                                        MetricTile(label: "ИМТ", value: latest.bmi.display, tint: AstraTheme.blue)
                                    }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Рецепты с высоким белком").font(.headline)
                            ForEach(dashboard.top) { recipe in RecipeRow(recipe: recipe) }
                        }
                    } else if isLoading { ProgressView().frame(maxWidth: .infinity).padding(40) }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                .padding()
            }
            .background(AstraTheme.canvas)
            .refreshable { await load() }
            .task { await load() }
            .navigationBarHidden(true)
        }
    }

    private func load() async {
        do { dashboard = try await session.api.dashboard(); error = nil }
        catch { error = error.localizedDescription }
        isLoading = false
    }
}

struct Header: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.largeTitle.weight(.bold)).foregroundStyle(AstraTheme.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(AstraTheme.muted)
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    var body: some View {
        AstraCard {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill").font(.title2).foregroundStyle(AstraTheme.green)
                VStack(alignment: .leading, spacing: 4) { Text(recipe.name).font(.headline); Text("\(recipe.category) · \(recipe.proteinPerServingG.display) г белка").font(.footnote).foregroundStyle(AstraTheme.muted) }
                Spacer()
                Text("\(recipe.kcalPerServing.display) ккал").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue)
            }
        }
    }
}

struct MoreView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @State private var showAPI = false
    @State private var apiURL = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Тренировки") { Button { tab = .workouts } label: { Label("Журнал тренировок", systemImage: "bolt.fill") } }
                Section("Прогресс") { Button { tab = .progress } label: { Label("Замеры и цели", systemImage: "chart.line.uptrend.xyaxis") } }
                Section("Профиль") {
                    LabeledContent("Email", value: session.user?.email ?? "—")
                    Button("Адрес API") { apiURL = session.api.baseURL; showAPI = true }
                    Button("Выйти", role: .destructive) { Task { await session.signOut() } }
                }
            }
            .navigationTitle("Ещё")
            .sheet(isPresented: $showAPI) {
                NavigationStack {
                    Form { TextField("https://astra.example.com/api/v1", text: $apiURL).textInputAutocapitalization(.never).autocorrectionDisabled() }
                        .navigationTitle("Адрес API")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { session.api.baseURL = apiURL; showAPI = false } } }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct DiaryView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var entries: [DiaryEntry] = []
    @State private var showAdd = false
    @State private var products: [Product] = []
    @State private var recipes: [Recipe] = []
    @State private var error: String?

    private var grouped: [(String, [DiaryEntry])] {
        Dictionary(grouping: entries, by: { $0.entryDate }).sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Header(title: "Дневник", subtitle: "Фиксируй питание без лишних шагов")
                    if let error { Text(error).foregroundStyle(.red) }
                    if grouped.isEmpty {
                        EmptyState(title: "Записей пока нет", message: "Добавь первый продукт или рецепт в дневник.", icon: "fork.knife")
                    } else {
                        ForEach(grouped.indices, id: \.self) { index in
                            let date = grouped[index].0
                            let dayEntries = grouped[index].1
                            VStack(alignment: .leading, spacing: 8) {
                                Text(date).font(.headline).padding(.top, 4)
                                ForEach(dayEntries) { entry in DiaryEntryRow(entry: entry) { remove(entry) } }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AstraTheme.canvas)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showAdd) { AddDiaryView(products: products, recipes: recipes) { await load() } }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func load() async {
        do {
            async let diary = session.api.diary()
            async let products = session.api.products()
            async let recipes = session.api.recipes()
            entries = try await diary
            self.products = try await products.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.recipes = try await recipes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            error = nil
        } catch { error = error.localizedDescription }
    }

    private func remove(_ entry: DiaryEntry) {
        Task {
            do { _ = try await session.api.deleteDiary(id: entry.id); await load() }
            catch { error = error.localizedDescription }
        }
    }
}

struct DiaryEntryRow: View {
    let entry: DiaryEntry
    let onDelete: () -> Void
    var body: some View {
        AstraCard {
            HStack(spacing: 12) {
                Image(systemName: entry.itemType == "product" ? "carrot.fill" : "fork.knife.circle.fill").foregroundStyle(entry.itemType == "product" ? AstraTheme.green : AstraTheme.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name ?? "Без названия").font(.headline)
                    Text("\(entry.mealType ?? "Приём пищи") · \(entry.kcalPerServing.display) ккал").font(.footnote).foregroundStyle(AstraTheme.muted)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
        }
    }
}

struct AddDiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let products: [Product]
    let recipes: [Recipe]
    let onSaved: () async -> Void
    @State private var isProduct = true
    @State private var productID: Int?
    @State private var recipeID: Int?
    @State private var meal = "Завтрак"
    @State private var amount = "1"
    @State private var date = Date()
    @State private var error: String?
    @State private var saving = false

    private let meals = ["Завтрак", "Обед", "Ужин", "Перекус", "Напиток", "Десерт"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип", selection: $isProduct) { Text("Продукт").tag(true); Text("Рецепт").tag(false) }.pickerStyle(.segmented)
                DatePicker("Дата", selection: $date, displayedComponents: .date)
                Picker("Приём пищи", selection: $meal) { ForEach(meals, id: \.self) { Text($0) } }
                if isProduct {
                    Picker("Продукт", selection: $productID) { Text("Выбрать").tag(nil as Int?); ForEach(products) { Text($0.name).tag(Optional($0.id)) } }
                } else {
                    Picker("Рецепт", selection: $recipeID) { Text("Выбрать").tag(nil as Int?); ForEach(recipes) { Text($0.name).tag(Optional($0.id)) } }
                }
                TextField(isProduct ? "Количество, грамм" : "Порций", text: $amount).keyboardType(.decimalPad)
                if let error { Text(error).foregroundStyle(.red) }
                Button(saving ? "Сохранение…" : "Добавить") { save() }.disabled(saving || (isProduct ? productID == nil : recipeID == nil))
            }
            .navigationTitle("В дневник")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }
    }

    private func save() {
        saving = true
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let numeric = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 1
        let payload = DiaryPayload(entryDate: formatter.string(from: date), items: [RecipePayload(recipeId: isProduct ? nil : recipeID, productId: isProduct ? productID : nil, mealType: meal, servings: isProduct ? 1 : numeric, quantity: isProduct ? numeric : nil, measurementName: nil)])
        Task {
            do { _ = try await session.api.createDiary(payload); await onSaved(); dismiss() }
            catch { error = error.localizedDescription; saving = false }
        }
    }
}

struct ProductsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var products: [Product] = []
    @State private var search = ""
    @State private var error: String?
    private var filtered: [Product] { products.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            List(filtered) { product in
                HStack(spacing: 12) {
                    Image(systemName: "carrot.fill").foregroundStyle(AstraTheme.green)
                    VStack(alignment: .leading) { Text(product.name).font(.headline); Text("\(product.category ?? "Без категории") · \(product.kcal.display) ккал").font(.caption).foregroundStyle(AstraTheme.muted) }
                    Spacer(); Text("Б \(product.proteinG.display) г").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue)
                }.padding(.vertical, 4)
            }
            .searchable(text: $search, prompt: "Найти продукт")
            .overlay { if products.isEmpty { if let error { Text(error).foregroundStyle(.red) } else { ProgressView() } } }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Продукты")
        }
    }
    private func load() async { do { products = try await session.api.products(); error = nil } catch { error = error.localizedDescription } }
}

struct RecipesView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var recipes: [Recipe] = []
    @State private var search = ""
    @State private var selected: Recipe?
    @State private var error: String?
    private var filtered: [Recipe] { recipes.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            List(filtered) { recipe in
                Button { selected = recipe } label: {
                    RecipeRow(recipe: recipe).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Найти рецепт")
            .overlay { if recipes.isEmpty { if let error { Text(error).foregroundStyle(.red) } else { ProgressView() } } }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Рецепты")
            .sheet(item: $selected) { RecipeDetailView(recipe: $0) }
        }
    }
    private func load() async { do { recipes = try await session.api.recipes(); error = nil } catch { error = error.localizedDescription } }
}

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let recipe: Recipe
    @State private var detail: RecipeDetail?

    var body: some View {
        NavigationStack {
            List {
                Section { Text(recipe.name).font(.title2.weight(.bold)); Text("\(recipe.kcalPerServing.display) ккал · Б \(recipe.proteinPerServingG.display) г · Ж \(recipe.fatPerServingG.display) г · У \(recipe.carbsPerServingG.display) г").font(.subheadline).foregroundStyle(AstraTheme.muted) }
                Section("Ингредиенты") {
                    if let detail { ForEach(detail.ingredients) { ingredient in Text("\(ingredient.name) — \(ingredient.quantity.display) \(ingredient.unit ?? "")") } }
                    else { ProgressView() }
                }
            }
            .navigationTitle("Рецепт")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .task { detail = try? await session.api.recipe(id: recipe.id) }
        }
    }
}

struct ProgressScreen: View {
    @EnvironmentObject private var session: SessionStore
    @State private var entries: [ProgressEntry] = []
    @State private var showAdd = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(entries) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.measuredAt).font(.headline)
                    HStack(spacing: 16) { Text("Вес \(item.weightKg.display) кг"); Text("Талия \(item.waistCm.display) см"); Text("ИМТ \(item.bmi.display)") }.font(.caption).foregroundStyle(AstraTheme.muted)
                    if let comment = item.comment, !comment.isEmpty { Text(comment).font(.footnote) }
                }.padding(.vertical, 5)
            }
            .overlay { if entries.isEmpty { if let error { Text(error).foregroundStyle(.red) } else { ProgressView() } } }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Прогресс")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddProgressView { await load() } }
        }
    }
    private func load() async { do { entries = try await session.api.progress(); error = nil } catch { error = error.localizedDescription } }
}

struct AddProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let onSaved: () async -> Void
    @State private var date = Date()
    @State private var weight = ""
    @State private var waist = ""
    @State private var wellbeing = ""
    @State private var comment = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Дата", selection: $date, displayedComponents: .date)
                TextField("Вес, кг", text: $weight).keyboardType(.decimalPad)
                TextField("Талия, см", text: $waist).keyboardType(.decimalPad)
                TextField("Самочувствие, 1–5", text: $wellbeing).keyboardType(.decimalPad)
                TextField("Комментарий", text: $comment, axis: .vertical)
                if let error { Text(error).foregroundStyle(.red) }
                Button("Сохранить") { save() }.disabled(weight.isEmpty)
            }
            .navigationTitle("Новый замер")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }
    }
    private func save() {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let number: (String) -> Double? = { Double($0.replacingOccurrences(of: ",", with: ".")) }
        let payload = ProgressPayload(measuredAt: formatter.string(from: date), weightKg: number(weight), desiredWeightKg: nil, heightCm: nil, waistCm: number(waist), wellbeingScore: number(wellbeing), comment: comment.isEmpty ? nil : comment)
        Task { do { _ = try await session.api.createProgress(payload); await onSaved(); dismiss() } catch { error = error.localizedDescription } }
    }
}

struct WorkoutsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var plans: [WorkoutPlan] = []
    @State private var logs: [WorkoutEntry] = []
    @State private var exercises: [Exercise] = []
    @State private var showAdd = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if !plans.isEmpty { Section("Планы") { ForEach(plans) { plan in WorkoutPlanRow(plan: plan) { complete(plan) } } } }
                Section("Журнал") {
                    if logs.isEmpty { Text("Пока нет записей").foregroundStyle(AstraTheme.muted) }
                    ForEach(logs) { log in VStack(alignment: .leading) { Text(log.name).font(.headline); Text("\(log.performedAt) · \(log.sets.display) подходов × \(log.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) } }
                }
            }
            .overlay { if plans.isEmpty && logs.isEmpty { if let error { Text(error).foregroundStyle(.red) } else { ProgressView() } } }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Тренировки")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddWorkoutView(exercises: exercises) { await load() } }
        }
    }
    private func load() async { do { async let plans = session.api.workoutPlans(); async let logs = session.api.workouts(); async let exercises = session.api.exercises(); self.plans = try await plans; self.logs = try await logs; self.exercises = try await exercises; error = nil } catch { error = error.localizedDescription } }
    private func complete(_ plan: WorkoutPlan) { Task { do { _ = try await session.api.completeWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }
}

struct WorkoutPlanRow: View {
    let plan: WorkoutPlan
    let onComplete: () -> Void
    var body: some View { HStack { VStack(alignment: .leading) { Text(plan.scheduledAt).font(.headline); Text("\(plan.items.count) упражнений · \(plan.status)").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); if plan.status == "planned" { Button("Готово", action: onComplete).buttonStyle(.borderedProminent).controlSize(.small) } } }
}

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let exercises: [Exercise]
    let onSaved: () async -> Void
    @State private var exerciseID: Int?
    @State private var weight = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var rir = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Упражнение", selection: $exerciseID) { Text("Выбрать").tag(nil as Int?); ForEach(exercises) { Text($0.name).tag(Optional($0.id)) } }
                TextField("Вес", text: $weight).keyboardType(.decimalPad)
                TextField("Подходы", text: $sets).keyboardType(.numberPad)
                TextField("Повторения", text: $reps).keyboardType(.numberPad)
                TextField("RIR", text: $rir)
                if let error { Text(error).foregroundStyle(.red) }
                Button("Сохранить") { save() }.disabled(exerciseID == nil)
            }
            .navigationTitle("Записать тренировку")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }
    }
    private func save() {
        let formatter = ISO8601DateFormatter()
        let number: (String) -> Double? = { Double($0.replacingOccurrences(of: ",", with: ".")) }
        guard let exerciseID else { return }
        let payload = WorkoutPayload(performedAt: formatter.string(from: Date()), exerciseId: exerciseID, workingWeight: number(weight), sets: number(sets), reps: number(reps), rir: rir.isEmpty ? nil : rir, comment: nil)
        Task { do { _ = try await session.api.createWorkout(payload); await onSaved(); dismiss() } catch { error = error.localizedDescription } }
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    let icon: String
    var body: some View { AstraCard { VStack(spacing: 8) { Image(systemName: icon).font(.largeTitle).foregroundStyle(AstraTheme.blue); Text(title).font(.headline); Text(message).font(.footnote).foregroundStyle(AstraTheme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 24) } }
}
