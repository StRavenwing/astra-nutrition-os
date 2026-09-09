import SwiftUI

enum AppTab: Hashable { case overview, diary, products, recipes, progress, workouts, trainer, information, catalog, settings }

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @AppStorage("astra_theme") private var theme = "dark"

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
            LinearGradient(colors: [AstraTheme.canvas, AstraTheme.surfaceElevated, AstraTheme.blue.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
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
                            MetricTile(label: "Одобрено", value: "\(dashboard.approved)", tint: AstraTheme.blue)
                            MetricTile(label: "Вес", value: dashboard.latest?.weightKg.display ?? "—", tint: AstraTheme.blue)
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

struct LegacyProgressScreen: View {
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

struct ProgressScreen: View {
    @EnvironmentObject private var session: SessionStore
    @State private var entries: [ProgressEntry] = []
    @State private var showAdd = false
    @State private var error: String?
    private let periods = ["Неделя", "Месяц", "3 месяца", "Год"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) { ForEach(periods, id: \.self) { period in Text(period).font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 9).background(period == "Месяц" ? AstraTheme.blue : AstraTheme.surface).foregroundStyle(period == "Месяц" ? Color.white : AstraTheme.ink).clipShape(Capsule()).overlay(Capsule().stroke(AstraTheme.line, lineWidth: 1)) } }
                    let latest = entries.first
                    let weights = entries.compactMap(\.weightKg).prefix(8).reversed()
                    AstraCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { VStack(alignment: .leading, spacing: 3) { Text("ДИНАМИКА ВЕСА").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Text("Последние 30 дней").font(.headline.weight(.bold)) }; Spacer(); Text("\(weights.count) замеров").font(.caption2).foregroundStyle(AstraTheme.muted) }
                            if weights.isEmpty { Text("Добавьте несколько замеров, чтобы увидеть динамику веса.").font(.caption).foregroundStyle(AstraTheme.muted).padding(.vertical, 28) }
                            else { let minValue = weights.min() ?? 0; let maxValue = weights.max() ?? minValue; let range = max(maxValue - minValue, 1); HStack(alignment: .bottom, spacing: 7) { ForEach(Array(weights.enumerated()), id: \.offset) { _, value in Rectangle().fill(AstraTheme.blue.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 34 + CGFloat((value - minValue) / range) * 78).clipShape(RoundedRectangle(cornerRadius: 5)) } }.frame(height: 126); HStack { Text(entries.last?.measuredAt ?? "").font(.caption2).foregroundStyle(AstraTheme.muted); Spacer(); Text(entries.first?.measuredAt ?? "").font(.caption2).foregroundStyle(AstraTheme.muted) } }
                        }
                    }
                    HStack(spacing: 10) { ProgressMetricMobile(label: "Вес", value: latest?.weightKg.display ?? "— кг"); ProgressMetricMobile(label: "ИМТ", value: latest?.bmi.display ?? "—"); ProgressMetricMobile(label: "Талия", value: latest?.waistCm.display ?? "— см") }
                    AstraCard { VStack(alignment: .leading, spacing: 9) { HStack { Text("Последние 30 дней").font(.headline.weight(.bold)); Spacer(); Text("\(entries.count) всего").font(.caption2).foregroundStyle(AstraTheme.muted) }; HStack(spacing: 5) { ForEach(0..<16, id: \.self) { index in RoundedRectangle(cornerRadius: 4).fill(index < min(entries.count, 16) ? AstraTheme.blue : AstraTheme.line).frame(maxWidth: .infinity).frame(height: 14) } } } }
                    HStack(spacing: 10) { ProgressMetricMobile(label: "Калории", value: latest?.kcalTarget.display ?? "— ккал"); ProgressMetricMobile(label: "Белок", value: latest?.proteinTargetG.display ?? "— г"); ProgressMetricMobile(label: "Самочувствие", value: latest?.wellbeingScore.display ?? "— / 5") }
                    HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 3) { Text("ИСТОРИЯ ЗАМЕРОВ").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Text("Открывайте карточку, чтобы посмотреть детали").font(.headline.weight(.bold)) }; Spacer(); Button { showAdd = true } label: { Label("Добавить", systemImage: "plus") }.buttonStyle(.bordered) }
                    if entries.isEmpty { Text(error ?? "Замеров пока нет").foregroundStyle(error == nil ? AstraTheme.muted : AstraTheme.danger).frame(maxWidth: .infinity).padding(32) }
                    else { LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) { ForEach(entries) { item in NavigationLink(value: item) { ProgressTileMobile(item: item) }.buttonStyle(.plain) } } }
                    AstraCard { VStack(alignment: .leading, spacing: 4) { Text("ПОДСКАЗКА").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Text("Добавляйте замеры примерно в одно и то же время").font(.subheadline.weight(.bold)); Text("Так динамика веса и объёмов будет сравниваться точнее.").font(.caption).foregroundStyle(AstraTheme.muted) } }
                }.padding()
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Прогресс")
            .navigationDestination(for: ProgressEntry.self) { item in ProgressDetailMobileView(entry: item, onChanged: load, onDeleted: load) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showAdd) { ProgressEditorMobileView(existing: nil) { await load() } }
        }
    }
    private func load() async { do { entries = try await session.api.progress(); error = nil } catch { error = error.localizedDescription } }
}

private struct ProgressMetricMobile: View {
    let label: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.muted); Text(value).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7) }.frame(maxWidth: .infinity, alignment: .leading).padding(11).background(AstraTheme.blue.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AstraTheme.line, lineWidth: 1)) }
}

private struct ProgressTileMobile: View {
    let item: ProgressEntry
    var body: some View { AstraCard { VStack(alignment: .leading, spacing: 7) { HStack { Text(item.measuredAt).font(.subheadline.weight(.bold)); Spacer(); Text("ЗАМЕР").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue) }; Divider(); Text("Вес").font(.caption).foregroundStyle(AstraTheme.muted); Text(item.weightKg.display + " кг").font(.title3.weight(.bold)); Text("Талия \(item.waistCm.display) см").font(.caption).foregroundStyle(AstraTheme.muted); Text("ИМТ \(item.bmi.display) · Самочувствие \(item.wellbeingScore.display) / 5").font(.caption2).foregroundStyle(AstraTheme.muted); Text("Открыть").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue).frame(maxWidth: .infinity).padding(.vertical, 8).background(AstraTheme.blue.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 8)) } } }
}

struct ProgressDetailMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let entry: ProgressEntry
    let onChanged: () async -> Void
    let onDeleted: () async -> Void
    @State private var showEditor = false
    @State private var showShare = false
    @State private var showDelete = false
    @State private var clients: [ClientSummary] = []
    @State private var hasTrainer = false
    @State private var actionMessage: String?
    @State private var actionError: String?
    private var canManage: Bool { session.user?.isAdmin == true || session.user?.isTrainer == true }

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) {
            AstraCard { VStack(alignment: .leading, spacing: 8) { Text("ТЕКУЩИЕ ПОКАЗАТЕЛИ").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Text(entry.weightKg.display + " кг").font(.system(size: 38, weight: .bold)); Text("Вес на дату замера").font(.caption).foregroundStyle(AstraTheme.muted); HStack(spacing: 8) { ProgressMetricMobile(label: "Цель", value: entry.desiredWeightKg.display + " кг"); ProgressMetricMobile(label: "ИМТ", value: entry.bmi.display) } } }
            AstraCard { VStack(alignment: .leading, spacing: 9) { Text("Подробности").font(.headline.weight(.bold)); ProgressDetailRowMobile("Талия", entry.waistCm.display + " см"); ProgressDetailRowMobile("Грудь", entry.chestCm.display + " см"); ProgressDetailRowMobile("Бёдра", entry.hipsCm.display + " см"); ProgressDetailRowMobile("Рост", entry.heightCm.display + " см"); ProgressDetailRowMobile("Процент жира", entry.bodyFatPct.display + " %"); ProgressDetailRowMobile("Мышечная масса", entry.muscleMassKg.display + " кг"); ProgressDetailRowMobile("Калорийность", entry.kcalTarget.display + " ккал"); ProgressDetailRowMobile("Белок", entry.proteinTargetG.display + " г"); ProgressDetailRowMobile("Жиры", entry.fatTargetG.display + " г"); ProgressDetailRowMobile("Углеводы", entry.carbsTargetG.display + " г"); ProgressDetailRowMobile("Сон", entry.sleepScore.display + " / 5"); ProgressDetailRowMobile("Самочувствие", entry.wellbeingScore.display + " / 5"); if let comment = entry.comment, !comment.isEmpty { Text(comment).font(.caption).foregroundStyle(AstraTheme.muted) } } }
            AstraCard { VStack(spacing: 9) { Button("Редактировать") { showEditor = true }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity); if canManage { Button("Отправить клиенту") { loadClients() }.buttonStyle(.bordered).frame(maxWidth: .infinity) }; if !canManage && hasTrainer { Button("Отправить тренеру") { sendToTrainer() }.buttonStyle(.bordered).frame(maxWidth: .infinity) }; Button("Удалить замер", role: .destructive) { showDelete = true }.frame(maxWidth: .infinity); if let actionMessage { Text(actionMessage).font(.caption).foregroundStyle(AstraTheme.green) }; if let actionError { Text(actionError).font(.caption).foregroundStyle(AstraTheme.danger) } } }
        }.padding() }.background(AstraTheme.canvas).navigationTitle("Замер").navigationBarTitleDisplayMode(.inline).task { if !canManage { hasTrainer = (try? await session.api.myTrainer()).map { $0.trainer != nil } ?? false } }.sheet(isPresented: $showEditor) { ProgressEditorMobileView(existing: entry) { await onChanged() } }.sheet(isPresented: $showShare) { ShareClientMobileView(clients: clients) { clientId in Task { do { _ = try await session.api.shareToClient(clientId: clientId, itemType: "progress", itemId: entry.id); actionMessage = "Отправлено клиенту"; actionError = nil; showShare = false } catch { actionError = error.localizedDescription } } } }.confirmationDialog("Удалить замер?", isPresented: $showDelete, titleVisibility: .visible) { Button("Удалить", role: .destructive) { delete() }; Button("Отмена", role: .cancel) {} } message: { Text("Это действие нельзя отменить.") }
    }
    private func loadClients() { Task { clients = (try? await session.api.clients()) ?? []; showShare = true } }
    private func sendToTrainer() { Task { do { _ = try await session.api.shareToTrainer(itemType: "progress", itemId: entry.id); actionMessage = "Отправлено тренеру"; actionError = nil } catch { actionError = error.localizedDescription } } }
    private func delete() { Task { do { _ = try await session.api.deleteProgress(id: entry.id); await onDeleted(); dismiss() } catch { actionError = error.localizedDescription } } }
}

private struct ProgressDetailRowMobile: View { let label: String; let value: String; init(_ label: String, _ value: String) { self.label = label; self.value = value }; var body: some View { HStack { Text(label).font(.caption).foregroundStyle(AstraTheme.muted); Spacer(); Text(value).font(.caption.weight(.bold)) } } }

struct ProgressEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let existing: ProgressEntry?
    let onSaved: () async -> Void
    @State private var date = ""
    @State private var weight = ""; @State private var desiredWeight = ""; @State private var height = ""; @State private var bodyFat = ""; @State private var muscleMass = ""; @State private var kcal = ""; @State private var protein = ""; @State private var fat = ""; @State private var carbs = ""; @State private var waist = ""; @State private var chest = ""; @State private var hips = ""; @State private var sleep = ""; @State private var wellbeing = ""; @State private var comment = ""; @State private var error: String?

    var body: some View { NavigationStack { Form { Section("Дата") { TextField("YYYY-MM-DD", text: $date) }; Section("Основные показатели") { ProgressNumberField("Вес, кг", text: $weight); ProgressNumberField("Желаемый вес, кг", text: $desiredWeight); ProgressNumberField("Рост, см", text: $height); ProgressNumberField("Талия, см", text: $waist); ProgressNumberField("Грудь, см", text: $chest); ProgressNumberField("Бёдра, см", text: $hips) }; Section("Состав тела") { ProgressNumberField("Процент жира", text: $bodyFat); ProgressNumberField("Мышечная масса, кг", text: $muscleMass) }; Section("Цели питания") { ProgressNumberField("Калорийность", text: $kcal); ProgressNumberField("Белок, г", text: $protein); ProgressNumberField("Жиры, г", text: $fat); ProgressNumberField("Углеводы, г", text: $carbs) }; Section("Самочувствие") { ProgressNumberField("Сон, 1–5", text: $sleep); ProgressNumberField("Самочувствие, 1–5", text: $wellbeing); TextField("Комментарий", text: $comment, axis: .vertical) }; if let error { Text(error).foregroundStyle(AstraTheme.danger) } }.navigationTitle(existing == nil ? "Новый замер" : "Редактировать замер").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(date.isEmpty) } }.onAppear { populate() } } }
    private func populate() { guard date.isEmpty else { return }; date = existing?.measuredAt ?? progressToday(); weight = existing?.weightKg.display == "—" ? "" : existing?.weightKg.display ?? ""; desiredWeight = existing?.desiredWeightKg.display == "—" ? "" : existing?.desiredWeightKg.display ?? ""; height = existing?.heightCm.display == "—" ? "" : existing?.heightCm.display ?? ""; bodyFat = existing?.bodyFatPct.display == "—" ? "" : existing?.bodyFatPct.display ?? ""; muscleMass = existing?.muscleMassKg.display == "—" ? "" : existing?.muscleMassKg.display ?? ""; kcal = existing?.kcalTarget.display == "—" ? "" : existing?.kcalTarget.display ?? ""; protein = existing?.proteinTargetG.display == "—" ? "" : existing?.proteinTargetG.display ?? ""; fat = existing?.fatTargetG.display == "—" ? "" : existing?.fatTargetG.display ?? ""; carbs = existing?.carbsTargetG.display == "—" ? "" : existing?.carbsTargetG.display ?? ""; waist = existing?.waistCm.display == "—" ? "" : existing?.waistCm.display ?? ""; chest = existing?.chestCm.display == "—" ? "" : existing?.chestCm.display ?? ""; hips = existing?.hipsCm.display == "—" ? "" : existing?.hipsCm.display ?? ""; sleep = existing?.sleepScore.display == "—" ? "" : existing?.sleepScore.display ?? ""; wellbeing = existing?.wellbeingScore.display == "—" ? "" : existing?.wellbeingScore.display ?? ""; comment = existing?.comment ?? "" }
    private func save() { Task { do { let payload = JSONPayload(values: ["measured_at": AnyEncodable(date), "weight_kg": progressNumber(weight), "desired_weight_kg": progressNumber(desiredWeight), "height_cm": progressNumber(height), "body_fat_pct": progressNumber(bodyFat), "muscle_mass_kg": progressNumber(muscleMass), "kcal_target": progressNumber(kcal), "protein_target_g": progressNumber(protein), "fat_target_g": progressNumber(fat), "carbs_target_g": progressNumber(carbs), "waist_cm": progressNumber(waist), "chest_cm": progressNumber(chest), "hips_cm": progressNumber(hips), "sleep_score": progressNumber(sleep), "wellbeing_score": progressNumber(wellbeing), "comment": progressText(comment)]); if let id = existing?.id { _ = try await session.api.updateProgress(id: id, payload: payload) } else { _ = try await session.api.createProgress(payload) }; await onSaved(); dismiss() } catch { error = error.localizedDescription } } }
}

private struct ProgressNumberField: View { let title: String; @Binding var text: String; init(_ title: String, text: Binding<String>) { self.title = title; self._text = text }; var body: some View { TextField(title, text: $text).keyboardType(.decimalPad) } }
private func progressNumber(_ value: String) -> AnyEncodable { AnyEncodable(Double(value.replacingOccurrences(of: ",", with: "."))) }
private func progressText(_ value: String) -> AnyEncodable { AnyEncodable(value.isEmpty ? nil : value) }
private func progressToday() -> String { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX"); return formatter.string(from: Date()) }

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
    var body: some View { HStack { VStack(alignment: .leading) { Text(plan.displayName).font(.headline); Text(plan.scheduledAt).font(.caption).foregroundStyle(AstraTheme.muted); Text("\(plan.items.count) упражнений · \(plan.status)").font(.caption2).foregroundStyle(AstraTheme.muted) }; Spacer(); if plan.status == "planned" { Button("Готово", action: onComplete).buttonStyle(.bordered).controlSize(.small) } } }
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
