import SwiftUI

private struct MobileMenuItem: Identifiable {
    let id: AppTab
    let title: String
    let icon: String
}

struct MobileMainView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var tab: AppTab = .overview

    private var menuItems: [MobileMenuItem] {
        var items = [MobileMenuItem(id: .overview, title: "Обзор", icon: "square.grid.2x2.fill")]
        if session.user?.isAdmin == true || session.user?.isTrainer == true { items.append(MobileMenuItem(id: .trainer, title: "Клиенты", icon: "person.2.fill")) }
        items += [
            MobileMenuItem(id: .diary, title: "Дневник", icon: "fork.knife"),
            MobileMenuItem(id: .workouts, title: "Тренировки", icon: "bolt.fill"),
            MobileMenuItem(id: .products, title: "Продукты", icon: "carrot.fill"),
            MobileMenuItem(id: .recipes, title: "Рецепты", icon: "book.closed.fill"),
            MobileMenuItem(id: .information, title: "Инфо", icon: "info.circle.fill"),
            MobileMenuItem(id: .settings, title: "Профиль", icon: "person.crop.circle.fill")
        ]
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            selectedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(menuItems) { item in
                        Button { tab = item.id } label: {
                            VStack(spacing: 3) {
                                Image(systemName: item.icon).font(.system(size: 17, weight: .semibold))
                                Text(item.title).font(.caption2.weight(tab == item.id ? .bold : .regular)).lineLimit(1)
                            }
                            .foregroundStyle(tab == item.id ? AstraTheme.blue : AstraTheme.muted)
                            .frame(width: 76, height: 48)
                            .background(tab == item.id ? AstraTheme.blue.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 8).padding(.vertical, 6)
            }
            .background(AstraTheme.surface)
            .overlay(alignment: .top) { Rectangle().fill(AstraTheme.line).frame(height: 1) }
        }
        .tint(AstraTheme.blue)
    }

    @ViewBuilder
    private var selectedView: some View {
        switch tab {
        case .overview: DashboardMobileView(onNavigate: { tab = $0 })
        case .trainer: TrainerView()
        case .diary: DiaryCalendarView()
        case .workouts: FitnessWorkoutsDashboardView()
        case .products: ProductsView()
        case .recipes: RecipesView()
        case .information: InformationView()
        case .settings: ProfileReferenceView(tab: $tab)
        case .catalog: CatalogMobileView()
        case .progress: ProgressScreen()
        default: DashboardMobileView(onNavigate: { tab = $0 })
        }
    }
}

struct DashboardMobileView: View {
    @EnvironmentObject private var session: SessionStore
    let onNavigate: (AppTab) -> Void
    @State private var dashboard: Dashboard?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Header(title: "Обзор", subtitle: "Фитнес, питание и контроль прогресса")
                    if let dashboard {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            dashboardTile("Продукты", "\(dashboard.products)", "carrot.fill", AstraTheme.blue) { onNavigate(.catalog) }
                            dashboardTile("Рецепты", "\(dashboard.recipes)", "book.closed.fill", AstraTheme.green) { onNavigate(.catalog) }
                            dashboardTile("Одобренные рецепты", "\(dashboard.approved)", "checkmark.seal.fill", AstraTheme.blue) { onNavigate(.catalog) }
                            dashboardTile("Вес", dashboard.latest?.weightKg.display ?? "—", "chart.line.uptrend.xyaxis", AstraTheme.blue) { onNavigate(.progress) }
                        }
                        Text("Плитка «Одобренные рецепты» показывает рецепты, прошедшие модерацию и доступные для использования в дневнике питания.")
                            .font(.caption)
                            .foregroundStyle(AstraTheme.muted)
                        if let latest = dashboard.latest {
                            Button { onNavigate(.progress) } label: {
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
                            }.buttonStyle(.plain)
                        }
                        HStack {
                            Text("Рецепты с высоким белком").font(.headline)
                            Spacer()
                            Button("Открыть каталог") { onNavigate(.catalog) }.font(.caption.weight(.bold))
                        }
                        ForEach(dashboard.top) { recipe in
                            Button { onNavigate(.catalog) } label: { RecipeRow(recipe: recipe) }.buttonStyle(.plain)
                        }
                    } else if error == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(40)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding()
            }
            .background(AstraTheme.canvas)
            .refreshable { await load() }
            .task { await load() }
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private func dashboardTile(_ label: String, _ value: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(AstraTheme.muted).multilineTextAlignment(.leading)
                Text(value).font(.title2.weight(.bold)).foregroundStyle(AstraTheme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(14)
            .background(tint.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func load() async {
        do { dashboard = try await session.api.dashboard(); error = nil }
        catch { error = error.localizedDescription }
    }
}

struct LegacyProfileReferenceView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @AppStorage("astra_theme") private var theme = "light"
    @State private var progress: [ProgressEntry] = []
    @State private var plans: [WorkoutPlan] = []
    @State private var showSettings = false
    @State private var error: String?

    private var latest: ProgressEntry? { progress.first }
    private var initial: String { String((session.user?.name ?? "A").prefix(1)).uppercased() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(initial)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 77, height: 77)
                            .background(AstraTheme.blue)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AstraTheme.blue, lineWidth: 3))
                        Text(session.user?.name ?? "Пользователь").font(.title2.weight(.bold)).foregroundStyle(AstraTheme.ink)
                        Text(session.user?.email ?? "—").font(.subheadline).foregroundStyle(AstraTheme.muted)
                    }
                    .padding(.top, 18)

                    AstraCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Замеры и цели").font(.headline)
                            profileMetric("Вес", latest?.weightKg.display.map { "\($0) кг" } ?? "Не задан")
                            profileMetric("Калории", latest?.kcalTarget.display.map { "\($0) ккал в день" } ?? "Не заданы")
                            profileMetric("Тренировки", plans.isEmpty ? "Нет планов" : "\(plans.count) запланировано")
                        }
                    }

                    VStack(spacing: 8) {
                        profileRow("Замеры и цели", icon: "chart.line.uptrend.xyaxis") { tab = .progress }
                        profileRow("Журнал тренировок", icon: "bolt.fill") { tab = .workouts }
                        profileRow("Чат с тренером", icon: "person.2.fill") { tab = .trainer }
                        profileRow("Продукты и рецепты", icon: "books.vertical.fill") { tab = .catalog }
                        profileRow("Статьи и информация", icon: "text.book.closed.fill") { tab = .information }
                        profileRow("Настройки", icon: "gearshape.fill") { showSettings = true }
                        Button { Task { await session.signOut() } } label: {
                            HStack { Text("Выйти").foregroundStyle(AstraTheme.danger); Spacer() }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 45)
                                .background(AstraTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(AstraTheme.danger) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AstraTheme.canvas)
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Toggle("Тёмная тема", isOn: Binding(get: { theme == "dark" }, set: { theme = $0 ? "dark" : "light" }))
                        Section("Подключение") {
                            LabeledContent("Адрес API", value: session.api.baseURL)
                        }
                    }
                    .navigationTitle("Настройки")
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func profileMetric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(AstraTheme.muted)
            Spacer()
            Text(value).foregroundStyle(AstraTheme.blue).fontWeight(.semibold)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(AstraTheme.line).frame(height: 1) }
    }

    @ViewBuilder
    private func profileRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title).foregroundStyle(AstraTheme.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.muted)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 45)
            .background(AstraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            async let p = session.api.progress()
            async let w = session.api.workoutPlans()
            progress = try await p
            plans = try await w
            error = nil
        } catch { error = error.localizedDescription }
    }
}

struct ProfileReferenceView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @AppStorage("astra_theme") private var theme = "light"
    @State private var progress: [ProgressEntry] = []
    @State private var plans: [WorkoutPlan] = []
    @State private var goalsExpanded = true
    @State private var showSettings = false

    private var latest: ProgressEntry? { progress.first }
    private var canManage: Bool { session.user?.isAdmin == true || session.user?.isTrainer == true }
    private var initial: String { String((session.user?.name ?? "A").prefix(1)).uppercased() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Header(title: "Профиль", subtitle: "Имя, цели, предпочтения и настройки")
                    AstraCard {
                        HStack(spacing: 12) {
                            Text(initial).font(.title2.weight(.bold)).foregroundStyle(.white).frame(width: 58, height: 58).background(AstraTheme.blue).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) { Text(session.user?.name ?? "Пользователь").font(.title3.weight(.bold)); Text(session.user?.email ?? "—").font(.caption).foregroundStyle(AstraTheme.muted); Text(canManage ? "Тренерский доступ" : "Пользователь").font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue) }
                            Spacer()
                        }
                    }
                    AstraCard { VStack(alignment: .leading, spacing: 7) { Label("Имя", systemImage: "person.fill").font(.headline); Text(session.user?.name ?? "Пользователь").font(.title3.weight(.bold)); Text(session.user?.email ?? "—").font(.caption).foregroundStyle(AstraTheme.muted) } }
                    Button { goalsExpanded.toggle() } label: {
                        AstraCard { HStack { Label("Цели и предпочтения", systemImage: "target").font(.headline); Spacer(); Text(goalsExpanded ? "Свернуть" : "Развернуть").font(.caption).foregroundStyle(AstraTheme.muted); Image(systemName: goalsExpanded ? "chevron.up" : "chevron.down").foregroundStyle(AstraTheme.muted) } }
                    }.buttonStyle(.plain)
                    if goalsExpanded {
                        AstraCard {
                            VStack(alignment: .leading, spacing: 0) {
                                ProfileMetricRow(title: "Вес", value: latest?.weightKg.display.map { "\($0) кг" } ?? "Не задан")
                                ProfileMetricRow(title: "Желаемый вес", value: latest?.desiredWeightKg.display.map { "\($0) кг" } ?? "Не задан")
                                ProfileMetricRow(title: "Калории", value: latest?.kcalTarget.display.map { "\($0) ккал в день" } ?? "Не заданы")
                                ProfileMetricRow(title: "Тренировки", value: plans.isEmpty ? "Нет планов" : "\(plans.count) запланировано")
                                Button("Открыть прогресс") { tab = .progress }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.top, 10)
                            }
                        }
                    }
                    DisabledProfileModule(title: "Пищевые привычки", subtitle: "В разработке", icon: "fork.knife")
                    Button { tab = .trainer } label: { ProfileModuleLabel(title: "Обратная связь", subtitle: "Связаться с тренером", icon: "bubble.left.and.bubble.right.fill") }.buttonStyle(.plain)
                    if !canManage { DisabledProfileModule(title: "Стать тренером", subtitle: "В разработке", icon: "figure.strengthtraining.traditional") }
                    Button { showSettings = true } label: { ProfileModuleLabel(title: "Настройки", subtitle: "Тема и подключение", icon: "gearshape.fill") }.buttonStyle(.plain)
                    Button { Task { await session.signOut() } } label: { HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Выйти"); Spacer() }.foregroundStyle(AstraTheme.danger).padding(16).frame(maxWidth: .infinity).background(AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1)) }.buttonStyle(.plain)
                }.padding()
            }
            .background(AstraTheme.canvas)
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showSettings) { NavigationStack { Form { Toggle("Тёмная тема", isOn: Binding(get: { theme == "dark" }, set: { theme = $0 ? "dark" : "light" })); Section("Подключение") { LabeledContent("Адрес API", value: session.api.baseURL) } }.navigationTitle("Настройки") } }
        }
    }
    private func load() async { do { async let p = session.api.progress(); async let w = session.api.workoutPlans(); progress = try await p; plans = try await w } catch { } }
}

private struct ProfileMetricRow: View { let title: String; let value: String; var body: some View { HStack { Text(title).foregroundStyle(AstraTheme.muted); Spacer(); Text(value).fontWeight(.semibold).foregroundStyle(AstraTheme.blue) }.padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(AstraTheme.line).frame(height: 1) } } }
private struct ProfileModuleLabel: View { let title: String; let subtitle: String; let icon: String; var body: some View { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(AstraTheme.blue).frame(width: 24); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.muted) }.padding(16).frame(maxWidth: .infinity).background(AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1)) } }
private struct DisabledProfileModule: View { let title: String; let subtitle: String; let icon: String; var body: some View { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(AstraTheme.muted).frame(width: 24); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(AstraTheme.muted); Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "lock.fill").font(.caption).foregroundStyle(AstraTheme.muted) }.padding(16).frame(maxWidth: .infinity).background(AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1)) } }

struct ProfileMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @AppStorage("astra_theme") private var theme = "light"
    @State private var showAPI = false
    @State private var apiURL = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Header(title: "Профиль", subtitle: "Аккаунт, настройки и разделы Astra")
                    AstraCard {
                        HStack(spacing: 14) {
                            Text(profileInitial)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(AstraTheme.blue)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.user?.name ?? "Пользователь").font(.title3.weight(.bold))
                                Text(session.user?.email ?? "—").font(.subheadline).foregroundStyle(AstraTheme.muted)
                                Text(roleTitle).font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue)
                            }
                            Spacer()
                        }
                    }

                    Text("Моя активность").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        profileTile("Замеры и цели", "Прогресс", "chart.line.uptrend.xyaxis", AstraTheme.blue) { tab = .progress }
                        profileTile("Журнал", "Тренировки", "bolt.fill", AstraTheme.green) { tab = .workouts }
                        profileTile("Обратная связь", "Тренер", "person.2.fill", AstraTheme.amber) { tab = .trainer }
                        profileTile("Материалы", "Информация", "info.circle.fill", AstraTheme.blue) { tab = .information }
                    }

                    Text("Настройки").font(.headline)
                    AstraCard {
                        VStack(spacing: 0) {
                            HStack {
                                Label("Тёмная тема", systemImage: "moon.fill")
                                Spacer()
                                Toggle("", isOn: Binding(get: { theme == "dark" }, set: { theme = $0 ? "dark" : "light" }))
                                    .labelsHidden()
                            }
                            Divider().overlay(AstraTheme.line)
                            Button { apiURL = session.api.baseURL; showAPI = true } label: {
                                profileActionLabel("Адрес API", subtitle: session.api.baseURL, icon: "server.rack")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Разделы").font(.headline)
                    AstraCard {
                        VStack(spacing: 0) {
                            Button { tab = .catalog } label: { profileActionLabel("Продукты и рецепты", subtitle: "Каталог веб-версии", icon: "books.vertical.fill") }.buttonStyle(.plain)
                            Divider().overlay(AstraTheme.line)
                            Button { tab = .information } label: { profileActionLabel("Статьи и информация", subtitle: "Полезные материалы", icon: "text.book.closed.fill") }.buttonStyle(.plain)
                        }
                    }

                    Button(role: .destructive) { Task { await session.signOut() } } label: {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .background(AstraTheme.canvas)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAPI) {
                NavigationStack {
                    Form { TextField("https://astra.example.com/api/v1", text: $apiURL).textInputAutocapitalization(.never).autocorrectionDisabled() }
                        .navigationTitle("Адрес API")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { session.api.baseURL = apiURL; showAPI = false } } }
                }.presentationDetents([.medium])
            }
        }
    }

    private var profileInitial: String { String((session.user?.name ?? "A").prefix(1)).uppercased() }
    private var roleTitle: String {
        if session.user?.isAdmin == true { return "Администратор" }
        if session.user?.isTrainer == true { return "Тренер" }
        return "Пользователь"
    }

    @ViewBuilder
    private func profileTile(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.caption.weight(.bold)).foregroundStyle(AstraTheme.ink)
                Text(subtitle).font(.caption2).foregroundStyle(AstraTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(14)
            .background(AstraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profileActionLabel(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AstraTheme.blue).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AstraTheme.ink)
                Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.muted)
        }
        .padding(.vertical, 9)
    }
}

struct MoreMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @AppStorage("astra_theme") private var theme = "light"
    @State private var showAPI = false
    @State private var apiURL = ""

    var body: some View {
        ProfileMobileView(tab: $tab)
    }
}

struct CatalogMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var mode = 0
    @State private var products: [Product] = []
    @State private var recipes: [Recipe] = []
    @State private var productCategories: [ContentCategory] = []
    @State private var recipeCategories: [ContentCategory] = []
    @State private var category = "Все"
    @State private var search = ""
    @State private var error: String?
    @State private var editingProduct: Product?
    @State private var editingRecipe: Recipe?
    @State private var showProductEditor = false
    @State private var showRecipeEditor = false
    @State private var showCatalogManage = false
    @State private var shareType: String?
    @State private var shareId: Int?
    @State private var clients: [ClientSummary] = []

    private var productCategoryNames: [String] { ["Все"] + productCategories.map(\.name) }
    private var recipeCategoryNames: [String] { ["Все"] + recipeCategories.map(\.name) }
    private var filteredProducts: [Product] { products.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (category == "Все" || $0.category == category) } }
    private var filteredRecipes: [Recipe] { recipes.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (category == "Все" || $0.category == category) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Раздел", selection: $mode) { Text("Продукты").tag(0); Text("Рецепты").tag(1) }.pickerStyle(.segmented).padding()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mode == 0 ? productCategoryNames : recipeCategoryNames, id: \.self) { name in
                            catalogCategoryTile(name)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                if mode == 0 {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(filteredProducts) { product in
                                NavigationLink { ProductDetailMobileView(product: product, onEdit: { editingProduct = product; showProductEditor = true }, onChanged: { Task { await load() } }) } label: {
                                    catalogFoodCard(name: product.name, category: product.category ?? "Без категории", kcal: product.kcal, protein: product.proteinG, fat: product.fatG, carbs: product.carbsG)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink { RecipeDetailMobileView(recipe: recipe, onEdit: { editingRecipe = recipe; showRecipeEditor = true }, onChanged: { Task { await load() } }) } label: {
                                    catalogFoodCard(name: recipe.name, category: recipe.category, kcal: recipe.kcalPerServing, protein: recipe.proteinPerServingG, fat: recipe.fatPerServingG, carbs: recipe.carbsPerServingG)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .searchable(text: $search, prompt: "Поиск в каталоге")
            .navigationTitle("Каталог")
            .onChange(of: mode) { _, _ in category = "Все" }
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { showCatalogManage = true } label: { Image(systemName: "slider.horizontal.3") }; Button { editingRecipe = nil; showRecipeEditor = true } label: { Image(systemName: "plus") } } }
            .overlay { if products.isEmpty && recipes.isEmpty && error == nil { ProgressView() } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showProductEditor) { ProductEditorMobileView(existing: editingProduct, onSave: { payload in Task { do { if let editingProduct { _ = try await session.api.updateProduct(id: editingProduct.id, payload: payload) } else { _ = try await session.api.createProduct(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingProduct == nil ? nil : { if let editingProduct { Task { do { _ = try await session.api.deleteProduct(id: editingProduct.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(isPresented: $showRecipeEditor) { RecipeEditorMobileView(existing: editingRecipe, products: products, onSave: { payload in Task { do { if let editingRecipe { _ = try await session.api.updateRecipe(id: editingRecipe.id, payload: payload) } else { _ = try await session.api.createRecipe(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingRecipe == nil ? nil : { if let editingRecipe { Task { do { _ = try await session.api.deleteRecipe(id: editingRecipe.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(isPresented: $showCatalogManage) { CatalogManagementMobileView(products: products, recipes: recipes, onEditProduct: { editingProduct = $0; showProductEditor = true }, onDeleteProduct: { product in Task { do { _ = try await session.api.deleteProduct(id: product.id); await load() } catch { error = error.localizedDescription } } }, onEditRecipe: { editingRecipe = $0; showRecipeEditor = true }, onDeleteRecipe: { recipe in Task { do { _ = try await session.api.deleteRecipe(id: recipe.id); await load() } catch { error = error.localizedDescription } } }, onShare: { type, id in shareType = type; shareId = id; Task { clients = (try? await session.api.clients()) ?? [] } }) }
            .sheet(item: Binding(get: { shareType.map { ShareSelection(type: $0, id: shareId ?? 0) } }, set: { _ in shareType = nil; shareId = nil })) { selection in ShareClientMobileView(clients: clients) { clientId in Task { do { _ = try await session.api.shareToClient(clientId: clientId, itemType: selection.type, itemId: selection.id) } catch { error = error.localizedDescription } } } }
        }
    }

    @ViewBuilder
    private func catalogCategoryTile(_ name: String) -> some View {
        Button { category = name } label: {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category == name ? AstraTheme.blue : AstraTheme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(category == name ? AstraTheme.blue.opacity(0.12) : AstraTheme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(category == name ? AstraTheme.blue : AstraTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            async let p = session.api.products(); async let r = session.api.recipes(); async let pc = session.api.categories(kind: "product"); async let rc = session.api.categories(kind: "recipe")
            products = try await p; recipes = try await r; productCategories = try await pc; recipeCategories = try await rc; error = nil
        } catch { error = error.localizedDescription }
    }

    @ViewBuilder
    private func catalogFoodCard(name: String, category: String, kcal: Double?, protein: Double?, fat: Double?, carbs: Double?) -> some View {
        AstraCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(category)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AstraTheme.muted)
                    .lineLimit(1)
                Text(name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AstraTheme.ink)
                    .lineLimit(3)
                Spacer(minLength: 14)
                HStack(spacing: 6) {
                    catalogMacro("ККАЛ", kcal.display)
                    catalogMacro("Б", protein.display + " г")
                    catalogMacro("Ж", fat.display + " г")
                    catalogMacro("У", carbs.display + " г")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        }
    }

    private func catalogMacro(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(AstraTheme.muted)
            Text(value).font(.system(size: 11, weight: .bold)).foregroundStyle(AstraTheme.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProductDetailMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let product: Product
    let onEdit: (() -> Void)?
    let onChanged: (() -> Void)?
    @State private var clients: [ClientSummary] = []
    @State private var hasTrainer = false
    @State private var showShareClients = false
    @State private var confirmDelete = false
    @State private var actionMessage: String?
    @State private var actionError: String?

    init(product: Product, onEdit: (() -> Void)? = nil, onChanged: (() -> Void)? = nil) {
        self.product = product
        self.onEdit = onEdit
        self.onChanged = onChanged
    }

    private var canManage: Bool { session.user?.isAdmin == true || session.user?.isTrainer == true }
    private var canEdit: Bool { session.user?.isAdmin == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AstraCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "carrot.fill").font(.system(size: 34)).foregroundStyle(AstraTheme.green)
                        Text(product.name).font(.title2.weight(.bold)).foregroundStyle(AstraTheme.ink)
                        Text(product.category ?? "Без категории").font(.subheadline).foregroundStyle(AstraTheme.muted)
                        Text("\(product.code) · \(product.unit ?? "г")").font(.caption).foregroundStyle(AstraTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                AstraCard {
                    HStack(spacing: 8) {
                        productMetric("Ккал", product.kcal.display, AstraTheme.blue)
                        productMetric("Белки", product.proteinG.display, AstraTheme.ink)
                        productMetric("Жиры", product.fatG.display, AstraTheme.ink)
                        productMetric("Угл.", product.carbsG.display, AstraTheme.ink)
                    }
                }
                AstraCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Параметры продукта").font(.headline).foregroundStyle(AstraTheme.ink)
                        Text("Цена за 100 г/ед.: \(product.pricePer100OrUnitRsd.display) RSD").font(.subheadline).foregroundStyle(AstraTheme.muted)
                        Text("Упаковка: \(product.packageSize.display) \(product.unit ?? "г") · \(product.packagePriceRsd.display) RSD").font(.subheadline).foregroundStyle(AstraTheme.muted)
                        if let note = product.note, !note.isEmpty { Text(note).font(.caption).foregroundStyle(AstraTheme.muted) }
                    }
                }
                productActions
            }
            .padding()
        }
        .background(AstraTheme.canvas)
        .navigationTitle("Продукт")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !canManage { hasTrainer = (try? await session.api.myTrainer()).map { $0.trainer != nil } ?? false } }
        .sheet(isPresented: $showShareClients) {
            ShareClientMobileView(clients: clients) { clientId in
                Task {
                    do { _ = try await session.api.shareToClient(clientId: clientId, itemType: "product", itemId: product.id); actionMessage = "Отправлено клиенту"; actionError = nil }
                    catch { actionError = error.localizedDescription }
                }
            }
        }
        .confirmationDialog("Удалить продукт?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { deleteProduct() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    @ViewBuilder
    private var productActions: some View {
        AstraCard {
            VStack(alignment: .leading, spacing: 10) {
                if canEdit {
                    Button("Редактировать") { dismiss(); onEdit?() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 8) {
                    if canManage {
                        Button("Отправить клиенту") { loadClientsAndPresent() }.buttonStyle(.bordered)
                    } else if hasTrainer {
                        Button("Отправить тренеру") { sendToTrainer() }.buttonStyle(.bordered)
                    }
                    if canEdit { Button("Удалить", role: .destructive) { confirmDelete = true }.buttonStyle(.bordered) }
                }
                if let actionMessage { Text(actionMessage).font(.caption).foregroundStyle(AstraTheme.green) }
                if let actionError { Text(actionError).font(.caption).foregroundStyle(AstraTheme.danger) }
            }
        }
    }

    private func productMetric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline.weight(.bold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(AstraTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadClientsAndPresent() {
        Task { clients = (try? await session.api.clients()) ?? []; showShareClients = true }
    }

    private func sendToTrainer() {
        Task {
            do { _ = try await session.api.shareToTrainer(itemType: "product", itemId: product.id); actionMessage = "Отправлено тренеру"; actionError = nil }
            catch { actionError = error.localizedDescription }
        }
    }

    private func deleteProduct() {
        Task {
            do { _ = try await session.api.deleteProduct(id: product.id); dismiss(); onChanged?() }
            catch { actionError = error.localizedDescription }
        }
    }
}

struct RecipeDetailMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var detail: RecipeDetail?
    @State private var error: String?
    @State private var clients: [ClientSummary] = []
    @State private var hasTrainer = false
    @State private var showShareClients = false
    @State private var confirmDelete = false
    @State private var actionMessage: String?
    @State private var actionError: String?
    let recipe: Recipe
    let onEdit: (() -> Void)?
    let onChanged: (() -> Void)?

    init(recipe: Recipe, onEdit: (() -> Void)? = nil, onChanged: (() -> Void)? = nil) {
        self.recipe = recipe
        self.onEdit = onEdit
        self.onChanged = onChanged
    }

    private var canManage: Bool { session.user?.isAdmin == true || session.user?.isTrainer == true }
    private var canEdit: Bool { session.user?.isAdmin == true || recipe.collection == "local" }
    private var isRevision: Bool { recipe.moderationStatus == "revision" && recipe.isSubmitter == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AstraCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AstraTheme.blue)
                        Text(recipe.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AstraTheme.ink)
                        Text(recipe.category)
                            .font(.subheadline)
                            .foregroundStyle(AstraTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    recipeInfoPill(recipe.category)
                    if let servings = recipe.servings { recipeInfoPill("\(servings.display) порц.") }
                    if let status = recipe.status, !status.isEmpty { recipeInfoPill(status) }
                }

                AstraCard {
                    HStack(spacing: 8) {
                        recipeMetric("Ккал", recipe.kcalPerServing.display, AstraTheme.blue)
                        recipeMetric("Белки", recipe.proteinPerServingG.display, AstraTheme.ink)
                        recipeMetric("Жиры", recipe.fatPerServingG.display, AstraTheme.ink)
                        recipeMetric("Угл.", recipe.carbsPerServingG.display, AstraTheme.ink)
                    }
                }

                Text("Ингредиенты")
                    .font(.headline)
                    .foregroundStyle(AstraTheme.ink)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(AstraTheme.danger)
                } else if let detail {
                    AstraCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(detail.ingredients) { ingredient in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(ingredient.name).foregroundStyle(AstraTheme.ink)
                                    Spacer(minLength: 10)
                                    Text("\(ingredient.quantity.display) \(ingredient.unit ?? "")")
                                        .font(.subheadline)
                                        .foregroundStyle(AstraTheme.muted)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                recipeActions
            }
            .padding()
        }
        .background(AstraTheme.canvas)
        .navigationTitle("Блюдо")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { detail = try await session.api.recipe(id: recipe.id) }
            catch { error = error.localizedDescription }
            if !canManage { hasTrainer = (try? await session.api.myTrainer()).map { $0.trainer != nil } ?? false }
        }
        .sheet(isPresented: $showShareClients) {
            ShareClientMobileView(clients: clients) { clientId in
                Task {
                    do { _ = try await session.api.shareToClient(clientId: clientId, itemType: "recipe", itemId: recipe.id); actionMessage = "Отправлено клиенту"; actionError = nil }
                    catch { actionError = error.localizedDescription }
                }
            }
        }
        .confirmationDialog("Удалить рецепт?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { deleteRecipe() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    @ViewBuilder
    private var recipeActions: some View {
        AstraCard {
            VStack(alignment: .leading, spacing: 10) {
                if canEdit {
                    Button("Редактировать") { dismiss(); onEdit?() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 8) {
                    if canManage {
                        Button("Отправить клиенту") { loadClientsAndPresent() }
                            .buttonStyle(.bordered)
                    } else if hasTrainer {
                        Button("Отправить тренеру") { sendToTrainer() }
                            .buttonStyle(.bordered)
                    }
                    if canEdit {
                        Button("Удалить", role: .destructive) { confirmDelete = true }
                            .buttonStyle(.bordered)
                    }
                }
                if isRevision {
                    if canEdit {
                        Button("Отправить повторно") { submitRecipe() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Отправить повторно") { submitRecipe() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Отменить отправку") { cancelSubmission() }
                        .buttonStyle(.bordered)
                } else if recipe.submissionRequested == true {
                    Button("Отменить отправку") { cancelSubmission() }
                        .buttonStyle(.bordered)
                } else if recipe.collection == "local" && canEdit {
                    Button("Отправить на проверку") { submitRecipe() }
                        .buttonStyle(.bordered)
                }
                if let actionMessage { Text(actionMessage).font(.caption).foregroundStyle(AstraTheme.green) }
                if let actionError { Text(actionError).font(.caption).foregroundStyle(AstraTheme.danger) }
            }
        }
    }

    private func loadClientsAndPresent() {
        Task {
            clients = (try? await session.api.clients()) ?? []
            showShareClients = true
        }
    }

    private func sendToTrainer() {
        Task {
            do { _ = try await session.api.shareToTrainer(itemType: "recipe", itemId: recipe.id); actionMessage = "Отправлено тренеру"; actionError = nil }
            catch { actionError = error.localizedDescription }
        }
    }

    private func submitRecipe() {
        Task {
            do { _ = try await session.api.requestRecipeSubmission(id: recipe.id); actionMessage = "Рецепт отправлен на проверку"; actionError = nil; onChanged?() }
            catch { actionError = error.localizedDescription }
        }
    }

    private func cancelSubmission() {
        Task {
            do { _ = try await session.api.cancelRecipeSubmission(id: recipe.id); actionMessage = "Отправка отменена"; actionError = nil; onChanged?() }
            catch { actionError = error.localizedDescription }
        }
    }

    private func deleteRecipe() {
        Task {
            do { _ = try await session.api.deleteRecipe(id: recipe.id); dismiss(); onChanged?() }
            catch { actionError = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func recipeInfoPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AstraTheme.blue)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(AstraTheme.blue.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AstraTheme.blue, lineWidth: 1))
    }

    @ViewBuilder
    private func recipeMetric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AstraTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ClientTrainerView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var chat: TrainerChatResponse?
    @State private var draft = ""
    @State private var error: String?
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let chat, let trainer = chat.trainer {
                    VStack(alignment: .leading, spacing: 3) { Text(trainer.name).font(.headline); Text(trainer.email).font(.caption).foregroundStyle(AstraTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(AstraTheme.surface)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(chat.messages) { message in
                                HStack { if message.senderId == session.user?.id { Spacer() }; Text(message.message).padding(12).background(message.senderId == session.user?.id ? AstraTheme.blue.opacity(0.16) : AstraTheme.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 14)); if message.senderId != session.user?.id { Spacer() } }
                            }
                        }.padding()
                    }
                    HStack { TextField("Сообщение тренеру", text: $draft, axis: .vertical).textFieldStyle(.roundedBorder); Button { send() } label: { Image(systemName: "paperplane.fill") }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending) }.padding()
                } else if chat != nil {
                    EmptyState(title: "Тренер пока не назначен", message: "Когда тренер будет подключён, здесь появится чат, рекомендации и обратная связь.", icon: "person.2.slash")
                } else if error == nil { ProgressView() } else { EmptyState(title: "Не удалось загрузить чат", message: error ?? "", icon: "wifi.exclamationmark") }
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Тренер")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async { do { chat = try await session.api.myTrainerChat(); error = nil } catch { error = error.localizedDescription } }
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; sending = true; draft = ""
        Task { do { let message = try await session.api.sendMyTrainerChat(message: text); chat?.messages.append(message) } catch { error = error.localizedDescription }; sending = false }
    }
}

struct TrainerView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        if session.user?.isAdmin == true || session.user?.isTrainer == true {
            TrainerClientsView()
        } else {
            ClientTrainerView()
        }
    }
}

struct TrainerClientsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var clients: [ClientSummary] = []
    @State private var selectedClient: ClientSummary?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Header(title: "Клиенты", subtitle: "Выберите клиента, чтобы открыть его данные и историю")
                    if let error { Text(error).foregroundStyle(AstraTheme.danger) }
                    if clients.isEmpty && error == nil {
                        EmptyState(title: "Клиентов пока нет", message: "Добавьте клиента в веб-версии или назначьте ему этого тренера.", icon: "person.2")
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(clients) { client in
                            Button { selectedClient = client } label: {
                                AstraCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(AstraTheme.blue)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(client.name).font(.headline)
                                            Text(client.email).font(.caption).foregroundStyle(AstraTheme.muted)
                                            if let next = client.nextWorkout { Text("Ближайшая тренировка: \(next.scheduledAt)").font(.caption2).foregroundStyle(AstraTheme.green) }
                                        }
                                        Spacer()
                                        if client.unreadMessages > 0 { Text("\(client.unreadMessages)").font(.caption.weight(.bold)).padding(7).background(AstraTheme.amber.opacity(0.18)).clipShape(Circle()) }
                                        Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding()
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Тренер")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { await load() }
            .navigationDestination(item: $selectedClient) { TrainerClientDetailView(client: $0) }
        }
    }

    private func load() async {
        do { clients = try await session.api.clients(); error = nil }
        catch { error = error.localizedDescription }
    }
}

struct TrainerClientDetailView: View {
    @EnvironmentObject private var session: SessionStore
    let client: ClientSummary
    @State private var detail: ClientDetail?
    @State private var selectedWorkout: WorkoutEntry?
    @State private var selectedPlan: WorkoutPlan?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let detail {
                    AstraCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(detail.name).font(.title2.weight(.bold))
                            Text(detail.email).font(.subheadline).foregroundStyle(AstraTheme.muted)
                            if let next = detail.nextWorkout { Label("Следующая тренировка: \(next.scheduledAt)", systemImage: "calendar.badge.clock").font(.caption).foregroundStyle(AstraTheme.green) }
                        }
                    }
                    clientMeasurements(detail)
                    clientNutrition(detail)
                    clientWorkouts(detail)
                    clientHistory(detail)
                } else if error == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(40)
                }
                if let error { Text(error).foregroundStyle(AstraTheme.danger) }
            }.padding()
        }
        .background(AstraTheme.canvas)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(destination: TrainerClientChatView(client: client)) { Image(systemName: "bubble.left.and.bubble.right.fill") } } }
        .navigationDestination(item: $selectedWorkout) { TrainerWorkoutDetailView(workout: $0) }
        .navigationDestination(item: $selectedPlan) { TrainerPlanDetailView(plan: $0) }
        .task { await load() }
    }

    @ViewBuilder private func clientMeasurements(_ detail: ClientDetail) -> some View {
        let latest = detail.progress.first
        AstraCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Последние замеры", systemImage: "chart.bar.xaxis").font(.headline)
                if let latest {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Вес", value: "\(latest.weightKg.display) кг", tint: AstraTheme.blue)
                        MetricTile(label: "Рост", value: "\(latest.heightCm.display) см", tint: AstraTheme.green)
                        MetricTile(label: "Жир", value: "\(latest.bodyFatPct.display)%", tint: AstraTheme.amber)
                        MetricTile(label: "Дата", value: latest.measuredAt, tint: AstraTheme.softBlue)
                    }
                } else { Text("Замеры ещё не добавлены.").foregroundStyle(AstraTheme.muted) }
            }
        }
    }

    @ViewBuilder private func clientNutrition(_ detail: ClientDetail) -> some View {
        AstraCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Label("Питание за сегодня", systemImage: "fork.knife").font(.headline); Spacer(); Text(detail.today.date).font(.caption).foregroundStyle(AstraTheme.muted) }
                if detail.today.entries.isEmpty { Text("Сегодня блюд и продуктов пока нет.").foregroundStyle(AstraTheme.muted) }
                ForEach(detail.today.entries) { entry in
                    HStack { Image(systemName: entry.itemType == "product" ? "carrot.fill" : "book.closed.fill").foregroundStyle(AstraTheme.green); VStack(alignment: .leading) { Text(entry.name ?? "Блюдо").font(.subheadline.weight(.semibold)); Text(entry.mealType ?? "Приём пищи").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Text("\(entry.kcalPerServing.display) ккал").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue) }
                }
                HStack(spacing: 10) {
                    MetricTile(label: "Съедено", value: "\(detail.today.totals.kcal.display) ккал", tint: AstraTheme.blue)
                    MetricTile(label: "Осталось", value: "\(detail.today.remaining.kcal.display) ккал", tint: AstraTheme.green)
                }
                Text("Б / Ж / У: \(detail.today.totals.protein.display) / \(detail.today.totals.fat.display) / \(detail.today.totals.carbs.display) г").font(.caption).foregroundStyle(AstraTheme.muted)
            }
        }
    }

    @ViewBuilder private func clientWorkouts(_ detail: ClientDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Запланированные тренировки").font(.headline); Spacer(); Text("\(detail.workoutPlans.filter { $0.status == \"planned\" }.count)").foregroundStyle(AstraTheme.blue) }
            ForEach(detail.workoutPlans.filter { $0.status == "planned" }) { plan in
                Button { selectedPlan = plan } label: { AstraCard { HStack { VStack(alignment: .leading) { Text(plan.scheduledAt).font(.subheadline.weight(.semibold)); Text(plan.items.compactMap(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } } }.buttonStyle(.plain)
            }
            if detail.workoutPlans.filter({ $0.status == "planned" }).isEmpty { Text("Планов пока нет.").font(.caption).foregroundStyle(AstraTheme.muted) }
        }
    }

    @ViewBuilder private func clientHistory(_ detail: ClientDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("История тренировок").font(.headline)
            ForEach(detail.workouts) { workout in
                Button { selectedWorkout = workout } label: { AstraCard { HStack { VStack(alignment: .leading) { Text(workout.name).font(.subheadline.weight(.semibold)); Text("\(workout.performedAt) · \(workout.sets.display) подходов × \(workout.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } } }.buttonStyle(.plain)
            }
            if detail.workouts.isEmpty { Text("История пока пуста.").font(.caption).foregroundStyle(AstraTheme.muted) }
        }
    }

    private func load() async {
        do { detail = try await session.api.client(id: client.id); error = nil }
        catch { error = error.localizedDescription }
    }
}

struct TrainerWorkspaceView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var clients: [ClientSummary] = []
    @State private var selected: ClientSummary?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section { Text(session.user?.isAdmin == true ? "Администраторский доступ: доступны все клиенты и тренерские инструменты." : "Клиенты, дневник, планы тренировок и чат.").font(.footnote).foregroundStyle(AstraTheme.muted) }
                if clients.isEmpty && error == nil { EmptyState(title: "Клиентов пока нет", message: "Добавьте клиента в веб-версии или назначьте ему этого тренера.", icon: "person.2") }
                ForEach(clients) { client in
                    Button { selected = client } label: {
                        HStack { Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(AstraTheme.blue); VStack(alignment: .leading) { Text(client.name).font(.headline); Text(client.email).font(.caption).foregroundStyle(AstraTheme.muted); if let next = client.nextWorkout { Text("Ближайшая тренировка: \(next.scheduledAt)").font(.caption2).foregroundStyle(AstraTheme.green) } }; Spacer(); if client.unreadMessages > 0 { Text("\(client.unreadMessages)").font(.caption.weight(.bold)).padding(7).background(AstraTheme.blue.opacity(0.18)).clipShape(Circle()) } }
                    }.buttonStyle(.plain)
                }
            }
            .overlay { if clients.isEmpty && error != nil { Text(error!).foregroundStyle(.red) } }
            .navigationTitle("Тренер")
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $selected) { client in TrainerClientChatView(client: client) }
        }
    }

    private func load() async { do { clients = try await session.api.clients(); error = nil } catch { error = error.localizedDescription } }
}

struct TrainerClientChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let client: ClientSummary
    @State private var messages: [TrainerChatMessage] = []
    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView { LazyVStack(alignment: .leading, spacing: 10) { ForEach(messages) { message in Text(message.message).padding(12).background(message.senderId == session.user?.id ? AstraTheme.blue.opacity(0.16) : AstraTheme.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 14)).frame(maxWidth: .infinity, alignment: message.senderId == session.user?.id ? .trailing : .leading) } }.padding() }
                HStack { TextField("Сообщение клиенту", text: $draft, axis: .vertical).textFieldStyle(.roundedBorder); Button { send() } label: { Image(systemName: "paperplane.fill") }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding()
            }.background(AstraTheme.canvas).navigationTitle(client.name).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }.task { messages = (try? await session.api.clientChat(id: client.id)) ?? [] }.overlay { if let error { Text(error).foregroundStyle(.red) } }
        }
    }

    private func send() { let text = draft.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; draft = ""; Task { do { messages.append(try await session.api.sendClientChat(id: client.id, message: text)) } catch { error = error.localizedDescription } } }
}

private enum TrainerWorkspaceSection: String, CaseIterable, Identifiable {
    case dashboard, clients, planned, history, exercises, complexes, machines, equipment
    var id: String { rawValue }
    var title: String { switch self { case .dashboard: return "Разделы"; case .clients: return "Клиенты"; case .planned: return "Планы тренировок"; case .history: return "История тренировок"; case .exercises: return "Упражнения"; case .complexes: return "Комплексы"; case .machines: return "Тренажёры"; case .equipment: return "Инвентарь" } }
    var icon: String { switch self { case .dashboard: return "square.grid.2x2.fill"; case .clients: return "person.2.fill"; case .planned: return "calendar.badge.clock"; case .history: return "clock.arrow.circlepath"; case .exercises: return "figure.strengthtraining.traditional"; case .complexes: return "rectangle.3.group.fill"; case .machines: return "figure.strengthtraining.traditional"; case .equipment: return "dumbbell.fill" } }
}

struct TrainerWorkspaceFullView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var section: TrainerWorkspaceSection = .dashboard
    @State private var clients: [ClientSummary] = []
    @State private var plans: [WorkoutPlan] = []
    @State private var history: [WorkoutEntry] = []
    @State private var exercises: [Exercise] = []
    @State private var complexes: [WorkoutComplex] = []
    @State private var equipment: [WorkoutEquipment] = []
    @State private var selectedClient: ClientSummary?
    @State private var selectedExercise: Exercise?
    @State private var selectedComplex: WorkoutComplex?
    @State private var selectedEquipment: WorkoutEquipment?
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedWorkout: WorkoutEntry?
    @State private var error: String?

    private var planned: [WorkoutPlan] { plans.filter { $0.status == "planned" } }
    private var completed: [WorkoutEntry] { history }
    private var machines: [WorkoutEquipment] { equipment.filter { $0.kind == "machine" } }
    private var freeEquipment: [WorkoutEquipment] { equipment.filter { $0.kind != "machine" } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if section != .dashboard {
                    HStack { Button { section = .dashboard } label: { Label("Разделы", systemImage: "chevron.left") }; Spacer(); Text(section.title).font(.headline); Spacer() }.padding(.horizontal).padding(.top, 8)
                }
                if section == .dashboard { dashboard } else { sectionContent }
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Тренер")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $selectedClient) { TrainerClientChatView(client: $0) }
            .navigationDestination(item: $selectedExercise) { TrainerExerciseDetailView(exercise: $0) }
            .navigationDestination(item: $selectedComplex) { TrainerComplexDetailView(complex: $0) }
            .navigationDestination(item: $selectedEquipment) { TrainerEquipmentDetailView(item: $0) }
#if false
            .sheet(isPresented: $showWorkoutManage) { WorkoutManagementMobileView(plans: plans, logs: logs, exercises: exercises, complexes: complexes, equipment: equipment, onEditPlan: { editingPlan = $0; planSourceComplex = nil; showPlanEditor = true }, onRepeatPlan: { editingPlan = $0; planSourceComplex = nil; showPlanEditor = true }, onCancelPlan: { plan in Task { do { _ = try await session.api.cancelWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }, onDeletePlan: { plan in Task { do { _ = try await session.api.deleteWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }, onEditWorkout: { editingWorkout = $0; showWorkoutEditor = true }, onRepeatWorkout: { workout in editingPlan = WorkoutPlan(id: 0, scheduledAt: workout.performedAt, durationMinutes: nil, status: "planned", completedAt: nil, items: [WorkoutPlanItem(id: nil, exerciseId: workout.exerciseId, name: workout.name, muscleGroup: workout.muscleGroup, workingWeight: workout.workingWeight, sets: workout.sets, durationMinutes: nil, speedKmh: nil)]); planSourceComplex = nil; showPlanEditor = true }, onDeleteWorkout: { workout in Task { do { _ = try await session.api.deleteWorkout(id: workout.id); await load() } catch { error = error.localizedDescription } } }, onEditExercise: { editingExercise = $0; showExerciseEditor = true }, onDeleteExercise: { exercise in Task { do { _ = try await session.api.deleteExercise(id: exercise.id); await load() } catch { error = error.localizedDescription } } }, onEditComplex: { editingComplex = $0; showComplexEditor = true }, onScheduleComplex: { planSourceComplex = $0; editingPlan = nil; showPlanEditor = true }, onEditEquipment: { editingEquipment = $0; showEquipmentEditor = true }, onDeleteEquipment: { item in Task { do { _ = try await session.api.deleteEquipment(id: item.id); await load() } catch { error = error.localizedDescription } } }, onShare: { type, id in Task { _ = try? await session.api.shareToTrainer(itemType: type, itemId: id); clients = (try? await session.api.clients()) ?? []; shareType = type; shareId = id } }) }
            .sheet(isPresented: $showPlanEditor) { WorkoutPlanEditorMobileView(initial: editingPlan, complex: planSourceComplex, exercises: exercises) { payload in Task { do { if let editingPlan, editingPlan.id > 0 { _ = try await session.api.updateWorkoutPlan(id: editingPlan.id, payload: payload) } else { _ = try await session.api.createWorkoutPlan(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showWorkoutEditor) { WorkoutEntryEditorMobileView(initial: editingWorkout, exercises: exercises) { payload in Task { do { if let editingWorkout { _ = try await session.api.updateWorkout(id: editingWorkout.id, payload: payload) } else { _ = try await session.api.createWorkout(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showComplexEditor) { WorkoutComplexEditorMobileView(initial: editingComplex, exercises: exercises) { payload in Task { do { if let editingComplex { _ = try await session.api.updateComplex(id: editingComplex.id, payload: payload) } else { _ = try await session.api.createComplex(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showExerciseEditor) { ExerciseEditorMobileView(existing: editingExercise, onSave: { payload in Task { do { if let editingExercise { _ = try await session.api.updateExercise(id: editingExercise.id, payload: payload) } else { _ = try await session.api.createExercise(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingExercise == nil ? nil : { if let editingExercise { Task { do { _ = try await session.api.deleteExercise(id: editingExercise.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(isPresented: $showEquipmentEditor) { EquipmentEditorMobileView(existing: editingEquipment, onSave: { payload in Task { do { if let editingEquipment { _ = try await session.api.updateEquipment(id: editingEquipment.id, payload: payload) } else { _ = try await session.api.createEquipment(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingEquipment == nil ? nil : { if let editingEquipment { Task { do { _ = try await session.api.deleteEquipment(id: editingEquipment.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(item: Binding(get: { shareType.map { ShareSelection(type: $0, id: shareId ?? 0) } }, set: { _ in shareType = nil; shareId = nil })) { selection in ShareClientMobileView(clients: clients) { clientId in Task { do { _ = try await session.api.shareToClient(clientId: clientId, itemType: selection.type, itemId: selection.id) } catch { error = error.localizedDescription } } } }
#endif
            .navigationDestination(item: $selectedPlan) { TrainerPlanDetailView(plan: $0) }
            .navigationDestination(item: $selectedWorkout) { TrainerWorkoutDetailView(workout: $0) }
        }
    }

    private var dashboard: some View {
        ScrollView { VStack(alignment: .leading, spacing: 14) {
            Header(title: "Тренерский workspace", subtitle: session.user?.isAdmin == true ? "Администратор: полный доступ к инструментам тренера" : "Клиенты, тренировки и справочники")
            if let error { Text(error).foregroundStyle(.red) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                trainerTile(.clients, value: "\(clients.count)")
                trainerTile(.planned, value: "\(planned.count)")
                trainerTile(.history, value: "\(completed.count)")
                trainerTile(.exercises, value: "\(exercises.count)")
                trainerTile(.complexes, value: "\(complexes.count)")
                trainerTile(.machines, value: "\(machines.count)")
                trainerTile(.equipment, value: "\(freeEquipment.count)")
            }
            Text("Все карточки открывают соответствующий раздел и детали элементов.").font(.caption).foregroundStyle(AstraTheme.muted)
        }.padding() }
    }

    @ViewBuilder private var sectionContent: some View {
        if let error { Text(error).foregroundStyle(.red).padding() }
        switch section {
        case .clients:
            List(clients) { client in Button { selectedClient = client } label: { HStack { Image(systemName: "person.crop.circle.fill").foregroundStyle(AstraTheme.blue); VStack(alignment: .leading) { Text(client.name).font(.headline); Text(client.email).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } }.buttonStyle(.plain) }
        case .planned:
            List(planned) { plan in Button { selectedPlan = plan } label: { HStack { VStack(alignment: .leading) { Text(plan.scheduledAt).font(.headline); Text("\(plan.items.count) упражнений · \(plan.status)").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right") } }.buttonStyle(.plain) }
        case .history:
            List(completed) { workout in Button { selectedWorkout = workout } label: { HStack { VStack(alignment: .leading) { Text(workout.name).font(.headline); Text("\(workout.performedAt) · \(workout.sets.display) подходов × \(workout.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right") } }.buttonStyle(.plain) }
        case .exercises:
            List(exercises) { exercise in Button { selectedExercise = exercise } label: { trainerListRow(icon: "figure.strengthtraining.traditional", title: exercise.name, subtitle: "\(exercise.muscleGroup ?? "Другое") · \(exercise.defaultSets.display) подхода × \(exercise.defaultReps.display) повторений") }.buttonStyle(.plain) }
        case .complexes:
            List(complexes) { complex in Button { selectedComplex = complex } label: { trainerListRow(icon: "rectangle.3.group.fill", title: complex.name, subtitle: "\(complex.items.count) упражнений") }.buttonStyle(.plain) }
        case .machines:
            List(machines) { item in Button { selectedEquipment = item } label: { trainerListRow(icon: "figure.strengthtraining.traditional", title: item.name, subtitle: item.description ?? "Тренажёр") }.buttonStyle(.plain) }
        case .equipment:
            List(freeEquipment) { item in Button { selectedEquipment = item } label: { trainerListRow(icon: "dumbbell.fill", title: item.name, subtitle: item.description ?? "Инвентарь") }.buttonStyle(.plain) }
        case .dashboard: EmptyView()
        }
    }

    @ViewBuilder private func trainerTile(_ item: TrainerWorkspaceSection, value: String) -> some View { Button { section = item } label: { VStack(alignment: .leading, spacing: 8) { Image(systemName: item.icon).foregroundStyle(item == .clients ? AstraTheme.blue : AstraTheme.green); Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(AstraTheme.muted).multilineTextAlignment(.leading); Text(value).font(.title2.weight(.bold)) }.frame(maxWidth: .infinity, minHeight: 100, alignment: .leading).padding(14).background(AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AstraTheme.line, lineWidth: 1)).shadow(color: AstraTheme.ink.opacity(0.06), radius: 8, y: 4) }.buttonStyle(.plain) }
    @ViewBuilder private func trainerListRow(icon: String, title: String, subtitle: String) -> some View { HStack { Image(systemName: icon).foregroundStyle(AstraTheme.green); VStack(alignment: .leading) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } }
    private func load() async { do { async let c = session.api.clients(); async let p = session.api.workoutPlans(); async let h = session.api.workouts(); async let e = session.api.exercises(); async let x = session.api.workoutComplexes(); async let i = session.api.workoutEquipment(); clients = try await c; plans = try await p; history = try await h; exercises = try await e; complexes = try await x; equipment = try await i; error = nil } catch { error = error.localizedDescription } }
}

private struct WorkoutReferenceHero: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.13))
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 176)
    }
}

private struct WorkoutReferenceBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(tint.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.7), lineWidth: 1))
    }
}

private struct WorkoutReferenceRow: View {
    let number: Int
    let title: String
    let value: String

    var body: some View {
        AstraCard {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AstraTheme.blue)
                    .frame(width: 32, height: 32)
                    .background(AstraTheme.blue.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AstraTheme.ink)
                    Text(value).font(.caption).foregroundStyle(AstraTheme.muted)
                }
                Spacer()
            }
        }
    }
}

struct TrainerExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                WorkoutReferenceHero(icon: "figure.strengthtraining.traditional", tint: AstraTheme.green)
                Text(exercise.name).font(.largeTitle.weight(.bold)).foregroundStyle(AstraTheme.ink)
                Text(exercise.muscleGroup ?? "Другое").font(.subheadline).foregroundStyle(AstraTheme.muted)
                HStack(spacing: 8) {
                    WorkoutReferenceBadge(title: exercise.muscleGroup ?? "Другое", tint: AstraTheme.green)
                    if let unit = exercise.defaultUnit, !unit.isEmpty { WorkoutReferenceBadge(title: unit, tint: AstraTheme.blue) }
                }
                Text("Параметры упражнения").font(.headline).foregroundStyle(AstraTheme.ink).padding(.top, 8)
                WorkoutReferenceRow(number: 1, title: "Единица нагрузки", value: exercise.defaultUnit ?? "—")
                WorkoutReferenceRow(number: 2, title: "Подходы", value: exercise.defaultSets.display)
                WorkoutReferenceRow(number: 3, title: "Повторения", value: exercise.defaultReps.display)
            }
            .padding()
        }
        .background(AstraTheme.canvas)
        .navigationTitle("Упражнение")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left") } } }
    }
}

struct TrainerComplexDetailView: View { @Environment(\.dismiss) private var dismiss; let complex: WorkoutComplex; var body: some View { NavigationStack { List { Section { Text(complex.name).font(.title2.weight(.bold)); if let comment = complex.comment { Text(comment) } }; Section("Упражнения") { ForEach(complex.items) { item in VStack(alignment: .leading) { Text(item.name).font(.headline); Text("\(item.sets.display) подхода · \(item.durationMinutes.display) мин").font(.caption).foregroundStyle(AstraTheme.muted) } } } }.navigationTitle("Комплекс").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerEquipmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: WorkoutEquipment

    var body: some View {
        let kind = item.kind == "machine" ? "Тренажёр" : "Инвентарь"
        let tint = item.kind == "machine" ? AstraTheme.green : AstraTheme.amber
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                WorkoutReferenceHero(icon: "dumbbell.fill", tint: tint)
                Text(item.name).font(.largeTitle.weight(.bold)).foregroundStyle(AstraTheme.ink)
                Text(kind).font(.subheadline).foregroundStyle(AstraTheme.muted)
                WorkoutReferenceBadge(title: kind, tint: tint)
                Text("Описание").font(.headline).foregroundStyle(AstraTheme.ink).padding(.top, 8)
                WorkoutReferenceRow(number: 1, title: "Тип", value: kind)
                WorkoutReferenceRow(number: 2, title: "Описание", value: item.description ?? "—")
            }
            .padding()
        }
        .background(AstraTheme.canvas)
        .navigationTitle(kind)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left") } } }
    }
}
struct TrainerPlanDetailView: View { @Environment(\.dismiss) private var dismiss; let plan: WorkoutPlan; var body: some View { NavigationStack { List { Section { Text(plan.scheduledAt).font(.title2.weight(.bold)); Text(plan.status).foregroundStyle(AstraTheme.muted) }; Section("Упражнения") { ForEach(plan.items) { item in VStack(alignment: .leading) { Text(item.name ?? "Упражнение").font(.headline); Text("\(item.sets.display) подхода · \(item.durationMinutes.display) мин").font(.caption).foregroundStyle(AstraTheme.muted) } } } }.navigationTitle("План").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerWorkoutDetailView: View { @Environment(\.dismiss) private var dismiss; let workout: WorkoutEntry; var body: some View { NavigationStack { List { Text(workout.name).font(.title2.weight(.bold)); LabeledContent("Дата", value: workout.performedAt); LabeledContent("Подходы", value: workout.sets.display); LabeledContent("Повторения", value: workout.reps.display); LabeledContent("Вес", value: workout.workingWeight.display); if let comment = workout.comment { Text(comment) } }.navigationTitle("История").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }

struct InformationView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var sections: [ArticleSection] = []
    @State private var articles: [Article] = []
    @State private var selectedSection: Int?
    @State private var search = ""
    @State private var selectedArticle: Article?
    @State private var editingArticle: Article?
    @State private var showArticleEditor = false
    @State private var showShareClients = false
    @State private var shareArticle: Article?
    @State private var clients: [ClientSummary] = []
    @State private var hasTrainer = false
    @State private var error: String?

    private var filtered: [Article] { articles.filter { (selectedSection == nil || $0.sectionId == selectedSection) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) || ($0.tags ?? "").localizedCaseInsensitiveContains(search)) } }
    private var pinned: [Article] { articles.filter { $0.isPinned && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) || ($0.tags ?? "").localizedCaseInsensitiveContains(search)) } }
    private var isAdmin: Bool { session.user?.isAdmin == true }
    private var canManage: Bool { isAdmin || session.user?.isTrainer == true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Header(title: "Информация", subtitle: "Питание, тренировки и полезные материалы")
                    if isAdmin { Button { editingArticle = nil; showArticleEditor = true } label: { Label("Добавить статью", systemImage: "plus") }.buttonStyle(.borderedProminent) }
                    if !pinned.isEmpty {
                        Text("Закреплённые статьи").font(.headline).foregroundStyle(AstraTheme.ink)
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(pinned) { article in articleCarousel(article) } } }
                    }
                    Text("Разделы статей").font(.headline).foregroundStyle(AstraTheme.ink)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        articleSectionTile(title: "Все", count: articles.count, selected: selectedSection == nil, icon: "square.grid.2x2.fill") { selectedSection = nil }
                        ForEach(sections) { section in
                            articleSectionTile(title: section.name, count: section.articleCount, selected: selectedSection == section.id, icon: articleSectionIcon(section.name)) { selectedSection = section.id }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    if filtered.isEmpty && error == nil { EmptyState(title: "Статей пока нет", message: "Материалы появятся здесь после публикации в веб-версии.", icon: "text.book.closed") }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) { ForEach(filtered) { article in articleTile(article) } }
                }.padding()
            }.background(AstraTheme.canvas).searchable(text: $search, prompt: "Найти статью").navigationTitle("Информация").task { await load() }.refreshable { await load() }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailMobileView(article: article, isAdmin: isAdmin, canManage: canManage, hasTrainer: hasTrainer, onEdit: { editingArticle = $0; showArticleEditor = true }, onChanged: replaceArticle, onDeleted: { articles.removeAll { $0.id == article.id }; selectedArticle = nil }, onShareClient: prepareShare, onShareTrainer: shareToTrainer)
            }
            .sheet(isPresented: $showArticleEditor) {
                ArticleEditorMobileView(existing: editingArticle, sections: sections, onSave: { payload in
                    Task { do { let updated: Article; if let item = editingArticle { updated = try await session.api.updateArticle(id: item.id, payload: payload); replaceArticle(updated) } else { updated = try await session.api.createArticle(payload); articles.append(updated) }; showArticleEditor = false } catch { error = error.localizedDescription } }
                }, onDelete: editingArticle == nil ? nil : { if let item = editingArticle { deleteArticle(item) } })
            }
            .sheet(isPresented: $showShareClients) {
                ShareClientMobileView(clients: clients) { clientId in
                    if let item = shareArticle { Task { do { _ = try await session.api.shareToClient(clientId: clientId, itemType: "article", itemId: item.id); showShareClients = false } catch { error = error.localizedDescription } } }
                }
            }
        }
    }

    @ViewBuilder private func articleSectionTile(title: String, count: Int, selected: Bool, icon: String, action: @escaping () -> Void) -> some View { Button(action: action) { AstraCard { HStack(spacing: 10) { Image(systemName: icon).font(.title3).foregroundStyle(selected ? AstraTheme.blue : AstraTheme.green).frame(width: 30); VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.weight(.bold)).foregroundStyle(selected ? AstraTheme.blue : AstraTheme.ink).lineLimit(2); Text("\(count) статей").font(.caption2).foregroundStyle(AstraTheme.muted) }; Spacer() }.frame(maxWidth: .infinity, minHeight: 66, alignment: .leading) } }.buttonStyle(.plain) }
    private func articleSectionIcon(_ title: String) -> String { let value = title.lowercased(); if value.contains("трен") || value.contains("упраж") { return "figure.strengthtraining.traditional" }; if value.contains("питан") || value.contains("рецеп") { return "fork.knife" }; return "text.book.closed.fill" }
    @ViewBuilder private func articleCarousel(_ article: Article) -> some View { Button { selectedArticle = article } label: { AstraCard { VStack(alignment: .leading, spacing: 6) { Text(article.sectionName.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Text(article.title).font(.headline).foregroundStyle(AstraTheme.ink).lineLimit(2); Text(article.body.plainText).font(.caption).foregroundStyle(AstraTheme.muted).lineLimit(2); Text("Читать статью →").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue) }.frame(width: 230, alignment: .leading) } }.buttonStyle(.plain) }
    @ViewBuilder private func articleTile(_ article: Article) -> some View { AstraCard { VStack(alignment: .leading, spacing: 7) { HStack { Text(article.sectionName.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Spacer(); if isAdmin { Button { toggleFlag(article, "isPinned") } label: { Image(systemName: article.isPinned ? "pin.fill" : "pin") }.buttonStyle(.bordered).controlSize(.mini) } }; Text(article.title).font(.headline.weight(.bold)).foregroundStyle(AstraTheme.ink).lineLimit(3).frame(minHeight: 47, alignment: .top); Text(article.body.plainText).font(.caption).foregroundStyle(AstraTheme.muted).lineLimit(3).frame(minHeight: 48, alignment: .top); Spacer(minLength: 2); Button { selectedArticle = article } label: { Text("Читать статью").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent); HStack(spacing: 4) { if isAdmin { Button { toggleFlag(article, "isHidden") } label: { Image(systemName: article.isHidden ? "arrow.uturn.backward" : "eye.slash") }.buttonStyle(.bordered).controlSize(.mini); Button { editingArticle = article; showArticleEditor = true } label: { Image(systemName: "pencil") }.buttonStyle(.bordered).controlSize(.mini) }; if canManage { Button { prepareShare(article) } label: { Image(systemName: "person.crop.circle.badge.plus") }.buttonStyle(.bordered).controlSize(.mini) }; if hasTrainer && !canManage { Button { shareToTrainer(article) } label: { Image(systemName: "paperplane") }.buttonStyle(.bordered).controlSize(.mini) } } }.frame(minHeight: 245, alignment: .top) } }
    private func replaceArticle(_ updated: Article) { if let index = articles.firstIndex(where: { $0.id == updated.id }) { articles[index] = updated }; if selectedArticle?.id == updated.id { selectedArticle = updated } }
    private func toggleFlag(_ article: Article, _ flag: String) { guard isAdmin else { return }; Task { do { let value = flag == "isPinned" ? !article.isPinned : !article.isHidden; let updated = try await session.api.updateArticleFlags(id: article.id, payload: JSONPayload(values: [flag == "isPinned" ? "is_pinned" : "is_hidden": AnyEncodable(value)])); replaceArticle(updated) } catch { error = error.localizedDescription } } }
    private func deleteArticle(_ article: Article) { Task { do { _ = try await session.api.deleteArticle(id: article.id); articles.removeAll { $0.id == article.id }; showArticleEditor = false } catch { error = error.localizedDescription } } }
    private func shareToTrainer(_ article: Article) { Task { do { _ = try await session.api.shareToTrainer(itemType: "article", itemId: article.id) } catch { error = error.localizedDescription } } }
    private func prepareShare(_ article: Article) { shareArticle = article; Task { clients = (try? await session.api.clients()) ?? []; showShareClients = true } }
    private func load() async { do { async let s = session.api.articleSections(); async let a = session.api.articles(); sections = try await s; articles = try await a; if !canManage { hasTrainer = (try? await session.api.myTrainer()).map { $0.trainer != nil } ?? false }; error = nil } catch { error = error.localizedDescription } }
}

struct ArticleDetailMobileView: View {
    @EnvironmentObject private var session: SessionStore
    let article: Article
    let isAdmin: Bool
    let canManage: Bool
    let hasTrainer: Bool
    let onEdit: (Article) -> Void
    let onChanged: (Article) -> Void
    let onDeleted: () -> Void
    let onShareClient: (Article) -> Void
    let onShareTrainer: (Article) -> Void
    @State private var current: Article
    @State private var showDelete = false
    @State private var error: String?
    init(article: Article, isAdmin: Bool = false, canManage: Bool = false, hasTrainer: Bool = false, onEdit: @escaping (Article) -> Void = { _ in }, onChanged: @escaping (Article) -> Void = { _ in }, onDeleted: @escaping () -> Void = {}, onShareClient: @escaping (Article) -> Void = { _ in }, onShareTrainer: @escaping (Article) -> Void = { _ in }) { self.article = article; self.isAdmin = isAdmin; self.canManage = canManage; self.hasTrainer = hasTrainer; self.onEdit = onEdit; self.onChanged = onChanged; self.onDeleted = onDeleted; self.onShareClient = onShareClient; self.onShareTrainer = onShareTrainer; _current = State(initialValue: article) }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 14) { Text(current.sectionName.uppercased()).font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue); Text(current.title).font(.largeTitle.weight(.bold)).foregroundStyle(AstraTheme.ink); Text(current.body.plainText).font(.body).foregroundStyle(AstraTheme.ink); if let tags = current.tags, !tags.isEmpty { Text(tags).font(.caption).foregroundStyle(AstraTheme.muted) }; ForEach(current.links, id: \.url) { link in if let url = URL(string: link.url) { Link(link.title, destination: url).foregroundStyle(AstraTheme.blue) } }; if let video = current.video, let url = URL(string: video) { Link("Видео", destination: url).foregroundStyle(AstraTheme.blue) }; Button { onEdit(current) } label: { Text("Редактировать").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent); if isAdmin { HStack { Button(current.isPinned ? "Открепить" : "Закрепить") { toggleFlag("is_pinned") }.buttonStyle(.bordered); Button(current.isHidden ? "Вернуть" : "Скрыть") { toggleFlag("is_hidden") }.buttonStyle(.bordered) }; Button("Удалить статью", role: .destructive) { showDelete = true }.frame(maxWidth: .infinity) }; if canManage { Button("Отправить клиенту") { onShareClient(current) }.buttonStyle(.bordered).frame(maxWidth: .infinity) }; if hasTrainer && !canManage { Button("Отправить тренеру") { onShareTrainer(current) }.buttonStyle(.bordered).frame(maxWidth: .infinity) }; if let error { Text(error).foregroundStyle(AstraTheme.danger) } }.padding() }.background(AstraTheme.canvas).navigationTitle("Статья").navigationBarTitleDisplayMode(.inline).confirmationDialog("Удалить статью?", isPresented: $showDelete, titleVisibility: .visible) { Button("Удалить", role: .destructive) { deleteArticle() }; Button("Отмена", role: .cancel) {} } message: { Text("Это действие нельзя отменить.") }
    }
    private func toggleFlag(_ flag: String) { Task { do { let updated = try await session.api.updateArticleFlags(id: current.id, payload: JSONPayload(values: [flag: AnyEncodable(flag == "is_pinned" ? !current.isPinned : !current.isHidden)])); current = updated; onChanged(updated) } catch { error = error.localizedDescription } } }
    private func deleteArticle() { Task { do { _ = try await session.api.deleteArticle(id: current.id); onDeleted() } catch { error = error.localizedDescription } } }
}

struct ArticleEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: Article?
    let sections: [ArticleSection]
    let onSave: (JSONPayload) -> Void
    let onDelete: (() -> Void)?
    @State private var sectionId = 0
    @State private var title = ""
    @State private var articleBody = ""
    @State private var tags = ""
    @State private var video = ""
    @State private var links = ""
    @State private var photos = ""
    var body: some View { NavigationStack { Form { Section("Статья") { if !sections.isEmpty { Picker("Раздел", selection: $sectionId) { ForEach(sections) { Text($0.name).tag($0.id) } } }; TextField("Заголовок", text: $title); TextField("Текст статьи", text: $articleBody, axis: .vertical); TextField("Хэштеги", text: $tags); TextField("Видео URL", text: $video) }; Section("Ссылки") { TextField("Название|URL, по одной в строке", text: $links, axis: .vertical) }; Section("Фото") { TextField("URL через запятую", text: $photos) }; if onDelete != nil { Button("Удалить статью", role: .destructive) { onDelete?() } } }.navigationTitle(existing == nil ? "Новая статья" : "Редактировать статью").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(payload) }.disabled(sectionId == 0 || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || articleBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.onAppear { sectionId = existing?.sectionId ?? sections.first?.id ?? 0; title = existing?.title ?? ""; articleBody = existing?.body.plainText ?? ""; tags = existing?.tags ?? ""; video = existing?.video ?? ""; links = existing?.links.map { "\($0.title)|\($0.url)" }.joined(separator: "\n") ?? ""; photos = existing?.photos.joined(separator: ", ") ?? "" } } }
    private var payload: JSONPayload { let linkValues = links.split(separator: "\n").compactMap { line -> JSONPayload? in let values = line.split(separator: "|", maxSplits: 1).map(String.init); guard values.count == 2, !values[0].trimmingCharacters(in: .whitespaces).isEmpty, !values[1].trimmingCharacters(in: .whitespaces).isEmpty else { return nil }; return JSONPayload(values: ["title": AnyEncodable(values[0].trimmingCharacters(in: .whitespaces)), "url": AnyEncodable(values[1].trimmingCharacters(in: .whitespaces))]) }; return JSONPayload(values: ["section_id": AnyEncodable(sectionId), "title": AnyEncodable(title), "body": AnyEncodable(articleBody), "tags": editorOptionalString(tags), "video": editorOptionalString(video), "links": AnyEncodable(linkValues), "photos": AnyEncodable(photos.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })]) }
}

private extension String { var plainText: String { replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression).replacingOccurrences(of: "&nbsp;", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) } }

struct FitnessWorkoutsDashboardView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var category: Int?
    @State private var plans: [WorkoutPlan] = []
    @State private var logs: [WorkoutEntry] = []
    @State private var exercises: [Exercise] = []
    @State private var complexes: [WorkoutComplex] = []
    @State private var equipment: [WorkoutEquipment] = []
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedWorkout: WorkoutEntry?
    @State private var selectedExercise: Exercise?
    @State private var selectedComplex: WorkoutComplex?
    @State private var selectedEquipment: WorkoutEquipment?
    @State private var showAdd = false
    @State private var showWorkoutManage = false
    @State private var showPlanEditor = false
    @State private var showWorkoutEditor = false
    @State private var showComplexEditor = false
    @State private var editingPlan: WorkoutPlan?
    @State private var editingWorkout: WorkoutEntry?
    @State private var editingComplex: WorkoutComplex?
    @State private var planSourceComplex: WorkoutComplex?
    @State private var editingExercise: Exercise?
    @State private var editingEquipment: WorkoutEquipment?
    @State private var showExerciseEditor = false
    @State private var showEquipmentEditor = false
    @State private var shareType: String?
    @State private var shareId: Int?
    @State private var clients: [ClientSummary] = []
    @State private var error: String?

    private var planned: [WorkoutPlan] { plans.filter { $0.status == "planned" } }

    var body: some View {
        NavigationStack {
            Group {
                if let category { categoryPage(category) } else { overview }
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Тренировки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { showWorkoutManage = true } label: { Image(systemName: "slider.horizontal.3") } } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showAdd) { AddWorkoutView(exercises: exercises) { await load() } }
            .sheet(isPresented: $showWorkoutManage) { WorkoutManagementMobileView(plans: plans, logs: logs, exercises: exercises, complexes: complexes, equipment: equipment, onEditPlan: { editingPlan = $0; planSourceComplex = nil; showPlanEditor = true }, onRepeatPlan: { editingPlan = $0; planSourceComplex = nil; showPlanEditor = true }, onCancelPlan: { plan in Task { do { _ = try await session.api.cancelWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }, onDeletePlan: { plan in Task { do { _ = try await session.api.deleteWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }, onEditWorkout: { editingWorkout = $0; showWorkoutEditor = true }, onRepeatWorkout: { workout in editingPlan = WorkoutPlan(id: 0, scheduledAt: workout.performedAt, durationMinutes: nil, status: "planned", completedAt: nil, items: [WorkoutPlanItem(id: nil, exerciseId: workout.exerciseId, name: workout.name, muscleGroup: workout.muscleGroup, workingWeight: workout.workingWeight, sets: workout.sets, durationMinutes: nil, speedKmh: nil)]); planSourceComplex = nil; showPlanEditor = true }, onDeleteWorkout: { workout in Task { do { _ = try await session.api.deleteWorkout(id: workout.id); await load() } catch { error = error.localizedDescription } } }, onEditExercise: { editingExercise = $0; showExerciseEditor = true }, onDeleteExercise: { exercise in Task { do { _ = try await session.api.deleteExercise(id: exercise.id); await load() } catch { error = error.localizedDescription } } }, onEditComplex: { editingComplex = $0; showComplexEditor = true }, onScheduleComplex: { planSourceComplex = $0; editingPlan = nil; showPlanEditor = true }, onEditEquipment: { editingEquipment = $0; showEquipmentEditor = true }, onDeleteEquipment: { item in Task { do { _ = try await session.api.deleteEquipment(id: item.id); await load() } catch { error = error.localizedDescription } } }, onShare: { type, id in Task { _ = try? await session.api.shareToTrainer(itemType: type, itemId: id); clients = (try? await session.api.clients()) ?? []; shareType = type; shareId = id } }) }
            .sheet(isPresented: $showPlanEditor) { WorkoutPlanEditorMobileView(initial: editingPlan, complex: planSourceComplex, exercises: exercises) { payload in Task { do { if let editingPlan, editingPlan.id > 0 { _ = try await session.api.updateWorkoutPlan(id: editingPlan.id, payload: payload) } else { _ = try await session.api.createWorkoutPlan(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showWorkoutEditor) { WorkoutEntryEditorMobileView(initial: editingWorkout, exercises: exercises) { payload in Task { do { if let editingWorkout { _ = try await session.api.updateWorkout(id: editingWorkout.id, payload: payload) } else { _ = try await session.api.createWorkout(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showComplexEditor) { WorkoutComplexEditorMobileView(initial: editingComplex, exercises: exercises) { payload in Task { do { if let editingComplex { _ = try await session.api.updateComplex(id: editingComplex.id, payload: payload) } else { _ = try await session.api.createComplex(payload) }; await load() } catch { error = error.localizedDescription } } } }
            .sheet(isPresented: $showExerciseEditor) { ExerciseEditorMobileView(existing: editingExercise, onSave: { payload in Task { do { if let editingExercise { _ = try await session.api.updateExercise(id: editingExercise.id, payload: payload) } else { _ = try await session.api.createExercise(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingExercise == nil ? nil : { if let editingExercise { Task { do { _ = try await session.api.deleteExercise(id: editingExercise.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(isPresented: $showEquipmentEditor) { EquipmentEditorMobileView(existing: editingEquipment, onSave: { payload in Task { do { if let editingEquipment { _ = try await session.api.updateEquipment(id: editingEquipment.id, payload: payload) } else { _ = try await session.api.createEquipment(payload) }; await load() } catch { error = error.localizedDescription } } }, onDelete: editingEquipment == nil ? nil : { if let editingEquipment { Task { do { _ = try await session.api.deleteEquipment(id: editingEquipment.id); await load() } catch { error = error.localizedDescription } } } }) }
            .sheet(item: Binding(get: { shareType.map { ShareSelection(type: $0, id: shareId ?? 0) } }, set: { _ in shareType = nil; shareId = nil })) { selection in ShareClientMobileView(clients: clients) { clientId in Task { do { _ = try await session.api.shareToClient(clientId: clientId, itemType: selection.type, itemId: selection.id) } catch { error = error.localizedDescription } } } }
            .navigationDestination(item: $selectedPlan) { TrainerPlanDetailView(plan: $0) }
            .navigationDestination(item: $selectedWorkout) { TrainerWorkoutDetailView(workout: $0) }
            .navigationDestination(item: $selectedExercise) { TrainerExerciseDetailView(exercise: $0) }
            .navigationDestination(item: $selectedComplex) { TrainerComplexDetailView(complex: $0) }
            .navigationDestination(item: $selectedEquipment) { TrainerEquipmentDetailView(item: $0) }
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Header(title: "Тренировки", subtitle: "План, упражнения и история нагрузки в одном месте")
                if let error { Text(error).foregroundStyle(AstraTheme.danger) }
                if !planned.isEmpty {
                    Text("Закреплённые тренировки").font(.headline)
                    ForEach(planned.prefix(3)) { plan in
                        Button { selectedPlan = plan } label: {
                            AstraCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(plan.scheduledAt).font(.headline)
                                        Text(plan.items.compactMap(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(AstraTheme.muted)
                                    }
                                    Spacer()
                                    Text("\(plan.items.count) упражн.").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.green)
                                    Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                Text("Разделы").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    workoutCategoryTile(title: "Тренировки", subtitle: "Комплексы и программы", count: plans.count, icon: "bolt.fill", color: AstraTheme.blue) { category = 0 }
                    workoutCategoryTile(title: "Упражнения", subtitle: "Справочник упражнений", count: exercises.count, icon: "figure.strengthtraining.traditional", color: AstraTheme.green) { category = 1 }
                    workoutCategoryTile(title: "Инвентарь", subtitle: "Оборудование и комплексы", count: equipment.count, icon: "dumbbell.fill", color: AstraTheme.amber) { category = 2 }
                    workoutCategoryTile(title: "История", subtitle: "Завершённые тренировки", count: logs.count, icon: "clock.arrow.circlepath", color: AstraTheme.blue) { category = 3 }
                }
            }.padding()
        }
    }

    @ViewBuilder private func workoutCategoryTile(title: String, subtitle: String, count: Int, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted).multilineTextAlignment(.leading)
                Text("\(count)").font(.title2.weight(.bold)).foregroundStyle(AstraTheme.blue)
            }.frame(maxWidth: .infinity, minHeight: 116, alignment: .leading).padding(14).background(AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func categoryPage(_ value: Int) -> some View {
        VStack(spacing: 0) {
            HStack { Button { category = nil } label: { Label("Разделы", systemImage: "chevron.left") }; Spacer(); Text(["Тренировки", "Упражнения", "Инвентарь", "История"][value]).font(.headline); Spacer() }.padding(.horizontal).padding(.vertical, 8)
            if value == 0 {
                List(plans) { plan in Button { selectedPlan = plan } label: { HStack { VStack(alignment: .leading) { Text(plan.scheduledAt).font(.headline); Text("\(plan.items.count) упражнений · \(plan.status)").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right") } }.buttonStyle(.plain) }
            } else if value == 1 {
                List(exercises) { exercise in Button { selectedExercise = exercise } label: { trainerListRow(icon: "figure.strengthtraining.traditional", title: exercise.name, subtitle: "\(exercise.muscleGroup ?? "Другое") · \(exercise.defaultSets.display) подхода × \(exercise.defaultReps.display) повторений") }.buttonStyle(.plain) }
            } else if value == 2 {
                List {
                    Section("Оборудование") { ForEach(equipment) { item in Button { selectedEquipment = item } label: { trainerListRow(icon: item.kind == "machine" ? "figure.strengthtraining.traditional" : "dumbbell.fill", title: item.name, subtitle: item.description ?? (item.kind == "machine" ? "Тренажёр" : "Инвентарь")) }.buttonStyle(.plain) } }
                    Section("Комплексы") { ForEach(complexes) { complex in Button { selectedComplex = complex } label: { trainerListRow(icon: "rectangle.3.group.fill", title: complex.name, subtitle: "\(complex.items.count) упражнений") }.buttonStyle(.plain) } }
                }
            } else {
                List(logs) { workout in Button { selectedWorkout = workout } label: { HStack { VStack(alignment: .leading) { Text(workout.name).font(.headline); Text("\(workout.performedAt) · \(workout.sets.display) подходов × \(workout.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right") } }.buttonStyle(.plain) }
            }
        }
    }

    @ViewBuilder private func trainerListRow(icon: String, title: String, subtitle: String) -> some View { HStack { Image(systemName: icon).foregroundStyle(AstraTheme.green); VStack(alignment: .leading) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } }
    private func load() async { do { async let p = session.api.workoutPlans(); async let l = session.api.workouts(); async let e = session.api.exercises(); async let c = session.api.workoutComplexes(); async let i = session.api.workoutEquipment(); plans = try await p; logs = try await l; exercises = try await e; complexes = try await c; equipment = try await i; error = nil } catch { error = error.localizedDescription } }
}

struct FitnessWorkoutsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var section = 0
    @State private var plans: [WorkoutPlan] = []
    @State private var logs: [WorkoutEntry] = []
    @State private var exercises: [Exercise] = []
    @State private var complexes: [WorkoutComplex] = []
    @State private var equipment: [WorkoutEquipment] = []
    @State private var selectedWorkout: WorkoutEntry?
    @State private var showAdd = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Раздел", selection: $section) { Text("Журнал").tag(0); Text("Упражнения").tag(1); Text("Комплексы").tag(2); Text("Инвентарь").tag(3) }.pickerStyle(.segmented).padding()
                Group {
                    if section == 0 {
                        List {
                            if !plans.isEmpty { Section("Планы") { ForEach(plans) { plan in WorkoutPlanRow(plan: plan) { complete(plan) } } } }
                            Section("Журнал") { ForEach(logs) { log in Button { selectedWorkout = log } label: { HStack { VStack(alignment: .leading) { Text(log.name).font(.headline); Text("\(log.performedAt) · \(log.sets.display) подходов × \(log.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AstraTheme.muted) } }.buttonStyle(.plain) } }
                        }
                    } else if section == 1 {
                        List(exercises) { exercise in VStack(alignment: .leading, spacing: 5) { Text(exercise.name).font(.headline); Text("\(exercise.muscleGroup ?? "Другое") · \(exercise.defaultSets.display) подхода × \(exercise.defaultReps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) } }
                    } else if section == 2 {
                        List(complexes) { complex in VStack(alignment: .leading, spacing: 5) { Text(complex.name).font(.headline); Text("\(complex.items.count) упражнений").font(.caption).foregroundStyle(AstraTheme.muted); if let comment = complex.comment { Text(comment).font(.footnote) } } }
                    } else {
                        List(equipment) { item in HStack { Image(systemName: item.kind == "machine" ? "figure.strengthtraining.traditional" : "dumbbell.fill").foregroundStyle(AstraTheme.green); VStack(alignment: .leading) { Text(item.name).font(.headline); Text(item.kind == "machine" ? "Тренажёр" : "Инвентарь").font(.caption).foregroundStyle(AstraTheme.muted) } } }
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal) }
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Тренировки")
            .toolbar { if section == 0 { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showAdd) { AddWorkoutView(exercises: exercises) { await load() } }
            .navigationDestination(item: $selectedWorkout) { TrainerWorkoutDetailView(workout: $0) }
        }
    }

    private func load() async {
        do { async let p = session.api.workoutPlans(); async let l = session.api.workouts(); async let e = session.api.exercises(); async let c = session.api.workoutComplexes(); async let i = session.api.workoutEquipment(); plans = try await p; logs = try await l; exercises = try await e; complexes = try await c; equipment = try await i; error = nil }
        catch { error = error.localizedDescription }
    }

    private func complete(_ plan: WorkoutPlan) { Task { do { _ = try await session.api.completeWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }
}

private func editorNumber(_ value: String) -> AnyEncodable { AnyEncodable(Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0) }
private func editorOptionalNumber(_ value: String) -> AnyEncodable { AnyEncodable(Double(value.replacingOccurrences(of: ",", with: "."))) }
private func editorOptionalString(_ value: String) -> AnyEncodable { AnyEncodable(value.isEmpty ? nil : value) }

private struct ShareSelection: Identifiable, Hashable { let type: String; let id: Int }

struct CatalogManagementMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let products: [Product]; let recipes: [Recipe]; let onEditProduct: (Product) -> Void; let onDeleteProduct: (Product) -> Void; let onEditRecipe: (Recipe) -> Void; let onDeleteRecipe: (Recipe) -> Void; let onShare: (String, Int) -> Void
    var body: some View { NavigationStack { List { Section("Продукты") { ForEach(products) { product in HStack { Text(product.name); Spacer(); Button("Изменить") { onEditProduct(product) }; Button("Отправить") { onShare("product", product.id) }.buttonStyle(.borderless); Button("Удалить", role: .destructive) { onDeleteProduct(product) }.buttonStyle(.borderless) } } }; Section("Блюда") { ForEach(recipes) { recipe in HStack { Text(recipe.name); Spacer(); Button("Изменить") { onEditRecipe(recipe) }; Button("Отправить") { onShare("recipe", recipe.id) }.buttonStyle(.borderless); Button("Удалить", role: .destructive) { onDeleteRecipe(recipe) }.buttonStyle(.borderless) } } } }.navigationTitle("Управление каталогом").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } }
}

struct ProductEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: Product?
    let onSave: (JSONPayload) -> Void
    let onDelete: (() -> Void)?
    @State private var name = ""; @State private var category = ""; @State private var unit = "г"; @State private var packagePrice = ""; @State private var packageSize = ""; @State private var pricePer100 = ""; @State private var kcal = ""; @State private var protein = "0"; @State private var fat = "0"; @State private var carbs = "0"; @State private var status = "Подтверждено"; @State private var note = ""
    var body: some View { NavigationStack { Form { Section("Основные данные") { TextField("Название", text: $name); TextField("Категория", text: $category); TextField("Единица", text: $unit); TextField("Статус данных", text: $status) }; Section("Упаковка и цена") { TextField("Цена упаковки, RSD", text: $packagePrice).keyboardType(.decimalPad); TextField("Размер упаковки", text: $packageSize).keyboardType(.decimalPad); TextField("Цена за 100 г / единицу, RSD", text: $pricePer100).keyboardType(.decimalPad) }; Section("КБЖУ") { TextField("Ккал", text: $kcal).keyboardType(.decimalPad); TextField("Белки, г", text: $protein).keyboardType(.decimalPad); TextField("Жиры, г", text: $fat).keyboardType(.decimalPad); TextField("Углеводы, г", text: $carbs).keyboardType(.decimalPad) }; Section("Примечание") { TextField("Примечание", text: $note, axis: .vertical) }; if onDelete != nil { Button("Удалить", role: .destructive) { onDelete?() } } }.navigationTitle(existing == nil ? "Новый продукт" : "Редактировать продукт").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(JSONPayload(values: ["name": AnyEncodable(name), "category": editorOptionalString(category), "unit": AnyEncodable(unit), "package_price_rsd": editorOptionalNumber(packagePrice), "package_size": editorOptionalNumber(packageSize), "price_per_100_or_unit_rsd": editorOptionalNumber(pricePer100), "kcal": editorOptionalNumber(kcal), "protein_g": editorNumber(protein), "fat_g": editorNumber(fat), "carbs_g": editorNumber(carbs), "data_status": AnyEncodable(status), "note": editorOptionalString(note)])); dismiss() }.disabled(name.isEmpty) } }.onAppear { name = existing?.name ?? ""; category = existing?.category ?? ""; unit = existing?.unit ?? "г"; packagePrice = existing?.packagePriceRsd?.display ?? ""; packageSize = existing?.packageSize?.display ?? ""; pricePer100 = existing?.pricePer100OrUnitRsd?.display ?? ""; kcal = existing?.kcal?.display ?? ""; protein = existing?.proteinG?.display ?? "0"; fat = existing?.fatG?.display ?? "0"; carbs = existing?.carbsG?.display ?? "0"; status = existing?.dataStatus ?? "Подтверждено"; note = existing?.note ?? "" } } }
}

struct RecipeEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: Recipe?
    let products: [Product]
    let onSave: (JSONPayload) -> Void
    let onDelete: (() -> Void)?
    @State private var category = ""; @State private var name = ""; @State private var subcategory = ""; @State private var version = "1.0"; @State private var servings = "1"; @State private var tags = ""; @State private var ready = false; @State private var garnish = false; @State private var price = ""; @State private var kcal = ""; @State private var protein = ""; @State private var fat = ""; @State private var carbs = ""; @State private var ingredientProductId = 0; @State private var ingredientQuantity = ""; @State private var ingredientUnit = "г"
    var body: some View { NavigationStack { Form { Section("Блюдо") { TextField("Категория", text: $category); TextField("Название", text: $name); TextField("Подкатегория", text: $subcategory); TextField("Версия", text: $version); TextField("Порций", text: $servings).keyboardType(.decimalPad); TextField("Теги", text: $tags); Toggle("Готово", isOn: $ready); Toggle("Нужен гарнир", isOn: $garnish) }; Section("Показатели на порцию") { TextField("Цена, RSD", text: $price).keyboardType(.decimalPad); TextField("Ккал", text: $kcal).keyboardType(.decimalPad); TextField("Белки, г", text: $protein).keyboardType(.decimalPad); TextField("Жиры, г", text: $fat).keyboardType(.decimalPad); TextField("Углеводы, г", text: $carbs).keyboardType(.decimalPad) }; Section("Ингредиенты") { if !products.isEmpty { Picker("Продукт", selection: Binding(get: { ingredientProductId == 0 ? products.first?.id ?? 0 : ingredientProductId }, set: { ingredientProductId = $0 })) { ForEach(products) { Text($0.name).tag($0.id) } } }; TextField("Количество", text: $ingredientQuantity).keyboardType(.decimalPad); TextField("Единица", text: $ingredientUnit) }; if onDelete != nil { Button("Удалить", role: .destructive) { onDelete?() } } }.navigationTitle(existing == nil ? "Новое блюдо" : "Редактировать блюдо").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { let ingredient = JSONPayload(values: ["product_id": AnyEncodable(ingredientProductId == 0 ? products.first?.id ?? 0 : ingredientProductId), "quantity": editorOptionalNumber(ingredientQuantity), "unit": AnyEncodable(ingredientUnit)]); onSave(JSONPayload(values: ["category": AnyEncodable(category), "name": AnyEncodable(name), "subcategory": editorOptionalString(subcategory), "version": AnyEncodable(version), "servings": editorNumber(servings), "tags": editorOptionalString(tags), "is_ready": AnyEncodable(ready), "needs_garnish": AnyEncodable(garnish), "manual_price_per_serving_rsd": editorOptionalNumber(price), "manual_kcal_per_serving": editorOptionalNumber(kcal), "manual_protein_per_serving_g": editorOptionalNumber(protein), "manual_fat_per_serving_g": editorOptionalNumber(fat), "manual_carbs_per_serving_g": editorOptionalNumber(carbs), "ingredients": AnyEncodable([ingredient])])); dismiss() }.disabled(name.isEmpty || category.isEmpty) } }.onAppear { category = existing?.category ?? ""; name = existing?.name ?? ""; subcategory = existing?.subcategory ?? ""; version = existing?.version ?? "1.0"; servings = existing?.servings?.display ?? "1"; tags = existing?.tags ?? ""; ready = existing?.isReady ?? false; garnish = existing?.needsGarnish ?? false; price = existing?.costPerServingRsd?.display ?? ""; kcal = existing?.kcalPerServing?.display ?? ""; protein = existing?.proteinPerServingG?.display ?? ""; fat = existing?.fatPerServingG?.display ?? ""; carbs = existing?.carbsPerServingG?.display ?? "" } } }
}

struct ExerciseEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: Exercise?
    let onSave: (JSONPayload) -> Void
    let onDelete: (() -> Void)?
    @State private var name = ""; @State private var muscle = ""; @State private var unit = "кг"; @State private var sets = "3"; @State private var reps = "12"; @State private var rir = "0–2"; @State private var note = ""; @State private var description = ""; @State private var photos = ""; @State private var video = ""; @State private var machine = ""; @State private var inventory = ""; @State private var technique = ""; @State private var tips = ""
    var body: some View { NavigationStack { Form { Section("Упражнение") { TextField("Название", text: $name); TextField("Мышечная группа", text: $muscle); TextField("Единица", text: $unit); TextField("Подходы", text: $sets).keyboardType(.decimalPad); TextField("Повторения", text: $reps).keyboardType(.decimalPad); TextField("Целевой RIR", text: $rir); TextField("Заметка", text: $note); TextField("Описание", text: $description, axis: .vertical); TextField("Фото URL через запятую", text: $photos); TextField("Видео URL", text: $video) }; Section("Вариант выполнения") { TextField("Тренажёр", text: $machine); TextField("Инвентарь", text: $inventory); TextField("Техника", text: $technique); TextField("Советы", text: $tips) }; if onDelete != nil { Button("Удалить", role: .destructive) { onDelete?() } } }.navigationTitle(existing == nil ? "Новое упражнение" : "Редактировать упражнение").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { let variants = [JSONPayload(values: ["machine": editorOptionalString(machine), "equipment": editorOptionalString(inventory), "description": editorOptionalString(description), "technique": editorOptionalString(technique), "tips": editorOptionalString(tips)])]; onSave(JSONPayload(values: ["name": AnyEncodable(name), "muscle_group": editorOptionalString(muscle), "default_unit": AnyEncodable(unit), "default_sets": editorNumber(sets), "default_reps": editorNumber(reps), "target_rir": editorOptionalString(rir), "note": editorOptionalString(note), "description": editorOptionalString(description), "photos": AnyEncodable(photos.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }), "video": editorOptionalString(video), "variants": AnyEncodable(variants)])); dismiss() }.disabled(name.isEmpty) } }.onAppear { name = existing?.name ?? ""; muscle = existing?.muscleGroup ?? ""; unit = existing?.defaultUnit ?? "кг"; sets = existing?.defaultSets?.display ?? "3"; reps = existing?.defaultReps?.display ?? "12"; rir = existing?.targetRir ?? "0–2"; note = existing?.note ?? ""; description = existing?.description ?? ""; photos = existing?.photos.joined(separator: ", ") ?? ""; video = existing?.video ?? ""; if let variant = existing?.variants.first { machine = variant.machine ?? ""; inventory = variant.equipment ?? ""; technique = variant.technique ?? ""; tips = variant.tips ?? "" } } } }
}

struct EquipmentEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: WorkoutEquipment?
    let onSave: (JSONPayload) -> Void
    let onDelete: (() -> Void)?
    @State private var kind = "equipment"; @State private var name = ""; @State private var description = ""; @State private var photo = ""
    var body: some View { NavigationStack { Form { Picker("Тип", selection: $kind) { Text("Тренажёр").tag("machine"); Text("Инвентарь").tag("equipment") }; TextField("Название", text: $name); TextField("Описание", text: $description, axis: .vertical); TextField("Фото URL", text: $photo); if onDelete != nil { Button("Удалить", role: .destructive) { onDelete?() } } }.navigationTitle(existing == nil ? "Новое оборудование" : "Редактировать оборудование").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(JSONPayload(values: ["kind": AnyEncodable(kind), "name": AnyEncodable(name), "description": editorOptionalString(description), "photo": editorOptionalString(photo)])); dismiss() }.disabled(name.isEmpty) } }.onAppear { kind = existing?.kind ?? "equipment"; name = existing?.name ?? ""; description = existing?.description ?? ""; photo = existing?.photo ?? "" } } }
}

struct ShareClientMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let clients: [ClientSummary]; let onShare: (Int) -> Void
    var body: some View { NavigationStack { List(clients) { client in Button { onShare(client.id); dismiss() } label: { VStack(alignment: .leading) { Text(client.name); Text(client.email).font(.caption).foregroundStyle(AstraTheme.muted) } } }.navigationTitle("Отправить клиенту").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } } } }
}

struct WorkoutPlanEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: WorkoutPlan?; let complex: WorkoutComplex?; let exercises: [Exercise]; let onSave: (JSONPayload) -> Void
    @State private var scheduledAt = ""; @State private var duration = ""; @State private var exerciseId = 0; @State private var weight = ""; @State private var sets = ""; @State private var itemDuration = ""; @State private var speed = ""
    init(initial: WorkoutPlan?, complex: WorkoutComplex?, exercises: [Exercise], onSave: @escaping (JSONPayload) -> Void) { self.initial = initial; self.complex = complex; self.exercises = exercises; self.onSave = onSave; let item = initial?.items.first ?? complex?.items.first.map { WorkoutPlanItem(id: $0.id, exerciseId: $0.exerciseId, name: $0.name, muscleGroup: $0.muscleGroup, workingWeight: $0.workingWeight, sets: $0.sets, durationMinutes: $0.durationMinutes, speedKmh: $0.speedKmh) }; _scheduledAt = State(initialValue: initial?.scheduledAt ?? ""); _duration = State(initialValue: initial?.durationMinutes?.display ?? ""); _exerciseId = State(initialValue: item?.exerciseId ?? exercises.first?.id ?? 0); _weight = State(initialValue: item?.workingWeight?.display ?? ""); _sets = State(initialValue: item?.sets?.display ?? ""); _itemDuration = State(initialValue: item?.durationMinutes?.display ?? ""); _speed = State(initialValue: item?.speedKmh?.display ?? "") }
    var body: some View { NavigationStack { Form { TextField("Дата и время", text: $scheduledAt); TextField("Длительность, мин", text: $duration).keyboardType(.decimalPad); if !exercises.isEmpty { Picker("Упражнение", selection: $exerciseId) { ForEach(exercises) { Text($0.name).tag($0.id) } } }; Section("Параметры упражнения") { TextField("Вес", text: $weight).keyboardType(.decimalPad); TextField("Подходы", text: $sets).keyboardType(.decimalPad); TextField("Длительность, мин", text: $itemDuration).keyboardType(.decimalPad); TextField("Скорость, км/ч", text: $speed).keyboardType(.decimalPad) } }.navigationTitle(initial == nil ? "Включить в план" : "Редактировать план").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { let item = JSONPayload(values: ["exercise_id": AnyEncodable(exerciseId), "working_weight": editorOptionalNumber(weight), "sets": editorOptionalNumber(sets), "duration_minutes": editorOptionalNumber(itemDuration), "speed_kmh": editorOptionalNumber(speed)]); onSave(JSONPayload(values: ["scheduled_at": AnyEncodable(scheduledAt), "duration_minutes": editorOptionalNumber(duration), "items": AnyEncodable([item])])); dismiss() } } } } }
}

struct WorkoutEntryEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: WorkoutEntry?; let exercises: [Exercise]; let onSave: (JSONPayload) -> Void
    @State private var performedAt = ""; @State private var exerciseId = 0; @State private var weight = ""; @State private var sets = ""; @State private var reps = ""; @State private var rir = ""; @State private var machine = ""; @State private var comment = ""
    init(initial: WorkoutEntry?, exercises: [Exercise], onSave: @escaping (JSONPayload) -> Void) { self.initial = initial; self.exercises = exercises; self.onSave = onSave; _performedAt = State(initialValue: initial?.performedAt ?? ""); _exerciseId = State(initialValue: initial?.exerciseId ?? exercises.first?.id ?? 0); _weight = State(initialValue: initial?.workingWeight?.display ?? ""); _sets = State(initialValue: initial?.sets?.display ?? ""); _reps = State(initialValue: initial?.reps?.display ?? ""); _rir = State(initialValue: initial?.rir ?? ""); _comment = State(initialValue: initial?.comment ?? "") }
    var body: some View { NavigationStack { Form { if !exercises.isEmpty { Picker("Упражнение", selection: $exerciseId) { ForEach(exercises) { Text($0.name).tag($0.id) } } }; TextField("Дата и время", text: $performedAt); TextField("Вес", text: $weight).keyboardType(.decimalPad); TextField("Подходы", text: $sets).keyboardType(.decimalPad); TextField("Повторения", text: $reps).keyboardType(.decimalPad); TextField("RIR", text: $rir); TextField("Место тренажёра", text: $machine); TextField("Комментарий", text: $comment, axis: .vertical) }.navigationTitle(initial == nil ? "Записать тренировку" : "Редактировать тренировку").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(JSONPayload(values: ["performed_at": AnyEncodable(performedAt), "exercise_id": AnyEncodable(exerciseId), "working_weight": editorOptionalNumber(weight), "sets": editorOptionalNumber(sets), "reps": editorOptionalNumber(reps), "rir": editorOptionalString(rir), "machine_location": editorOptionalString(machine), "comment": editorOptionalString(comment)])); dismiss() } } } } }
}

struct WorkoutComplexEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: WorkoutComplex?; let exercises: [Exercise]; let onSave: (JSONPayload) -> Void
    @State private var name = ""; @State private var comment = ""; @State private var video = ""; @State private var exerciseId = 0; @State private var weight = ""; @State private var sets = ""; @State private var itemDuration = ""; @State private var speed = ""
    init(initial: WorkoutComplex?, exercises: [Exercise], onSave: @escaping (JSONPayload) -> Void) { self.initial = initial; self.exercises = exercises; self.onSave = onSave; self._name = State(initialValue: initial?.name ?? ""); self._comment = State(initialValue: initial?.comment ?? ""); self._video = State(initialValue: initial?.video ?? ""); let item = initial?.items.first; self._exerciseId = State(initialValue: item?.exerciseId ?? exercises.first?.id ?? 0); self._weight = State(initialValue: item?.workingWeight?.display ?? ""); self._sets = State(initialValue: item?.sets?.display ?? ""); self._itemDuration = State(initialValue: item?.durationMinutes?.display ?? ""); self._speed = State(initialValue: item?.speedKmh?.display ?? "") }
    var body: some View { NavigationStack { Form { TextField("Название", text: $name); TextField("Комментарий", text: $comment, axis: .vertical); TextField("Видео URL", text: $video); if !exercises.isEmpty { Picker("Упражнение", selection: $exerciseId) { ForEach(exercises) { Text($0.name).tag($0.id) } } }; TextField("Вес", text: $weight).keyboardType(.decimalPad); TextField("Подходы", text: $sets).keyboardType(.decimalPad); TextField("Длительность, мин", text: $itemDuration).keyboardType(.decimalPad); TextField("Скорость, км/ч", text: $speed).keyboardType(.decimalPad) }.navigationTitle(initial == nil ? "Новый комплекс" : "Редактировать комплекс").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { let item = JSONPayload(values: ["exercise_id": AnyEncodable(exerciseId), "working_weight": editorOptionalNumber(weight), "sets": editorOptionalNumber(sets), "duration_minutes": editorOptionalNumber(itemDuration), "speed_kmh": editorOptionalNumber(speed)]); onSave(JSONPayload(values: ["name": AnyEncodable(name), "comment": editorOptionalString(comment), "photos": AnyEncodable([String]()), "video": editorOptionalString(video), "items": AnyEncodable([item])])); dismiss() } }.disabled(name.isEmpty) } } }
}

struct WorkoutManagementMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let plans: [WorkoutPlan]; let logs: [WorkoutEntry]; let exercises: [Exercise]; let complexes: [WorkoutComplex]; let equipment: [WorkoutEquipment]
    let onEditPlan: (WorkoutPlan) -> Void; let onRepeatPlan: (WorkoutPlan) -> Void; let onCancelPlan: (WorkoutPlan) -> Void; let onDeletePlan: (WorkoutPlan) -> Void; let onEditWorkout: (WorkoutEntry) -> Void; let onRepeatWorkout: (WorkoutEntry) -> Void; let onDeleteWorkout: (WorkoutEntry) -> Void; let onEditExercise: (Exercise) -> Void; let onDeleteExercise: (Exercise) -> Void; let onEditComplex: (WorkoutComplex) -> Void; let onScheduleComplex: (WorkoutComplex) -> Void; let onEditEquipment: (WorkoutEquipment) -> Void; let onDeleteEquipment: (WorkoutEquipment) -> Void; let onShare: (String, Int) -> Void
    var body: some View { NavigationStack { List { Section("Планы") { ForEach(plans) { item in HStack { Text(item.scheduledAt); Spacer(); Button("Изм.") { onEditPlan(item) }; Button("Повт.") { onRepeatPlan(item) }; if item.status == "planned" { Button("Отм.") { onCancelPlan(item) } }; Button("Удал.", role: .destructive) { onDeletePlan(item) } } } }; Section("История") { ForEach(logs) { item in HStack { Text(item.name); Spacer(); Button("Изм.") { onEditWorkout(item) }; Button("Повт.") { onRepeatWorkout(item) }; Button("Удал.", role: .destructive) { onDeleteWorkout(item) } } } }; Section("Упражнения") { ForEach(exercises) { item in HStack { Text(item.name); Spacer(); Button("Изм.") { onEditExercise(item) }; Button("Отправить") { onShare("exercise", item.id) }.buttonStyle(.borderless) } } }; Section("Комплексы") { ForEach(complexes) { item in HStack { Text(item.name); Spacer(); Button("Изм.") { onEditComplex(item) }; Button("В план") { onScheduleComplex(item) }; Button("Отправить") { onShare("workout_complex", item.id) }.buttonStyle(.borderless) } } }; Section("Оборудование") { ForEach(equipment) { item in HStack { Text(item.name); Spacer(); Button("Изм.") { onEditEquipment(item) }; Button("Удал.", role: .destructive) { onDeleteEquipment(item) }; Button("Отправить") { onShare("workout_equipment", item.id) }.buttonStyle(.borderless) } } } }.navigationTitle("Действия тренировки").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } }
}

private let diaryMealOrderMobile = ["Завтрак", "Обед", "Ужин", "Перекус", "Напиток", "Десерт"]

private struct MobileDiaryTotals {
    var kcal: Double = 0; var protein: Double = 0; var fat: Double = 0; var carbs: Double = 0; var cost: Double = 0
}

private func mobileDiaryTotals(_ entries: [DiaryEntry]) -> MobileDiaryTotals {
    entries.reduce(into: MobileDiaryTotals()) { totals, entry in
        let factor = entry.itemType == "product" ? 1 : (entry.servings ?? 1)
        totals.kcal += (entry.kcalPerServing ?? 0) * factor
        totals.protein += (entry.proteinPerServingG ?? 0) * factor
        totals.fat += (entry.fatPerServingG ?? 0) * factor
        totals.carbs += (entry.carbsPerServingG ?? 0) * factor
        totals.cost += (entry.costPerServingRsd ?? 0) * factor
    }
}

private func mobileDiaryISO(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX"); return formatter.string(from: date) }
private func mobileDiaryDate(_ value: String) -> Date { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX"); return formatter.date(from: value) ?? Date() }
private func mobileDiaryMonthTitle(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "LLLL yyyy"; formatter.locale = Locale(identifier: "ru_RU"); return formatter.string(from: date).capitalized }
private func mobileDiaryNumber(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value) }

struct DiaryCalendarView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var entries: [DiaryEntry] = []
    @State private var products: [Product] = []
    @State private var recipes: [Recipe] = []
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var error: String?

    private var today: String { mobileDiaryISO(Date()) }
    private var monthDays: [Date] { guard let range = Calendar.current.range(of: .day, in: .month, for: month), let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: month)) else { return [] }; return range.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: start) } }
    private var monthOffset: Int { guard let first = monthDays.first else { return 0 }; let weekday = Calendar.current.component(.weekday, from: first); return (weekday + 5) % 7 }
    private var currentEntries: [DiaryEntry] { entries.filter { $0.entryDate == today } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Header(title: "Дневник", subtitle: "Food Calendar · питание по дням")
                    if let error { Text(error).foregroundStyle(.red) }
                    currentDayCard
                    currentMealsCard
                    calendarCard
                }
                .padding()
            }
            .background(AstraTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { await load() }
            .navigationDestination(for: String.self) { date in
                DiaryDayEditorMobileView(date: date, entries: entries.filter { $0.entryDate == date }, products: products, recipes: recipes) { await load() }
            }
        }
    }

    private var currentDayCard: some View {
        let totals = mobileDiaryTotals(currentEntries)
        return AstraCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Text("FOOD CALENDAR").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.green); Text("Сегодня · \(today)").font(.title3.weight(.bold)) }; Spacer(); NavigationLink(value: today) { Text("Сегодня").font(.caption.weight(.bold)) }.buttonStyle(.borderedProminent) }
                HStack(spacing: 8) { mobileDiaryMetric("ККАЛ", mobileDiaryNumber(totals.kcal), AstraTheme.blue); mobileDiaryMetric("БЕЛОК", "\(mobileDiaryNumber(totals.protein)) г", AstraTheme.green); mobileDiaryMetric("ЗАПИСЕЙ", "\(currentEntries.count)", AstraTheme.blue) }
                Text("Жиры \(mobileDiaryNumber(totals.fat)) г · Углеводы \(mobileDiaryNumber(totals.carbs)) г").font(.caption).foregroundStyle(AstraTheme.muted)
            }
        }
    }

    private var currentMealsCard: some View {
        AstraCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { VStack(alignment: .leading, spacing: 3) { Text("ТЕКУЩИЙ ДЕНЬ").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue); Text("Питание по приёмам").font(.headline) }; Spacer(); NavigationLink("Изменить", value: today).font(.caption.weight(.bold)) }
                if currentEntries.isEmpty { Text("Записей пока нет — откройте день и добавьте блюдо или продукт.").font(.subheadline).foregroundStyle(AstraTheme.muted) }
                else { ForEach(diaryMealOrderMobile, id: \.self) { meal in let mealEntries = currentEntries.filter { $0.mealType == meal }; if !mealEntries.isEmpty { HStack(spacing: 10) { Text(String(meal.prefix(1))).font(.headline.weight(.bold)).foregroundStyle(AstraTheme.green).frame(width: 30, height: 30).background(AstraTheme.green.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 3) { Text(meal).font(.subheadline.weight(.bold)); Text(mealEntries.compactMap(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Text("\(mobileDiaryNumber(mobileDiaryTotals(mealEntries).kcal)) ккал").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue) } } } }
            }
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) { VStack(alignment: .leading, spacing: 3) { Text("КАЛЕНДАРЬ ПИТАНИЯ").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.green); Text("Нажмите на день для редактирования").font(.headline) }; Spacer(); Button("Сегодня") { month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date() }.font(.caption.weight(.bold)) }
            HStack { Button("‹") { month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month }; Spacer(); Text(mobileDiaryMonthTitle(month)).font(.subheadline.weight(.bold)); Spacer(); Button("›") { month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month } }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { Text($0).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.muted) }
                ForEach(0..<(monthOffset + monthDays.count), id: \.self) { index in
                    if index < monthOffset { Color.clear.frame(height: 70) }
                    else { let date = monthDays[index - monthOffset]; let iso = mobileDiaryISO(date); let dayEntries = entries.filter { $0.entryDate == iso }; NavigationLink(value: iso) { VStack(alignment: .leading, spacing: 4) { Text(String(Calendar.current.component(.day, from: date))).font(.subheadline.weight(.bold)); Text(dayEntries.isEmpty ? "Нет записей" : "\(dayEntries.count) · \(mobileDiaryNumber(mobileDiaryTotals(dayEntries).kcal)) ккал").font(.system(size: 9)).foregroundStyle(AstraTheme.muted).multilineTextAlignment(.leading) }.frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading).padding(7).background(iso == today ? AstraTheme.green.opacity(0.18) : AstraTheme.surface).clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(iso == today ? AstraTheme.green : AstraTheme.line, lineWidth: 1)) }.buttonStyle(.plain) }
                }
            }
        }
        .padding(14)
        .background(AstraTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
    }

    private func mobileDiaryMetric(_ label: String, _ value: String, _ color: Color) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.muted); Text(value).font(.headline.weight(.bold)).foregroundStyle(color) }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10)) }
    private func load() async { do { async let diary = session.api.diary(); async let productList = session.api.products(); async let recipeList = session.api.recipes(); entries = try await diary; products = try await productList.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }; recipes = try await recipeList.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }; error = nil } catch { error = error.localizedDescription } }
}

struct DiaryDayEditorMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let date: String; let entries: [DiaryEntry]; let products: [Product]; let recipes: [Recipe]; let onChanged: () async -> Void
    @State private var editing: DiaryEntry?
    @State private var showAdd = false

    var body: some View {
        List {
            let totals = mobileDiaryTotals(entries)
            Section { HStack { diaryDayStat("Записей", "\(entries.count)"); diaryDayStat("Ккал", mobileDiaryNumber(totals.kcal)); diaryDayStat("Белок", "\(mobileDiaryNumber(totals.protein)) г") } }
            ForEach(diaryMealOrderMobile, id: \.self) { meal in
                let mealEntries = entries.filter { $0.mealType == meal }
                if !mealEntries.isEmpty { Section(meal) { ForEach(mealEntries) { entry in Button { editing = entry } label: { HStack { Image(systemName: entry.itemType == "product" ? "carrot.fill" : "fork.knife.circle.fill").foregroundStyle(AstraTheme.green); VStack(alignment: .leading, spacing: 4) { Text(entry.name ?? "Без названия").font(.headline); Text(entry.itemType == "product" ? "\(mobileDiaryNumber(entry.measurementQuantity ?? entry.quantity ?? 0)) \(entry.measurementName ?? entry.unit ?? "г")" : "\(mobileDiaryNumber(entry.servings ?? 1)) порций").font(.caption).foregroundStyle(AstraTheme.muted); if let comment = entry.comment, !comment.isEmpty { Text(comment).font(.caption2).foregroundStyle(AstraTheme.muted) } }; Spacer(); Text("\(mobileDiaryNumber(mobileDiaryTotals([entry]).kcal)) ккал").font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue) } }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { delete(entry) } label: { Label("Удалить", systemImage: "trash") } } } } }
            }
            if entries.isEmpty { Section { Text("В этот день записей пока нет. Добавьте блюдо, ингредиент или новое блюдо.").foregroundStyle(AstraTheme.muted) } }
        }
        .navigationTitle(date)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { DiaryFoodPickerMobileView(date: date, products: products, recipes: recipes) { await onChanged() } }
        .sheet(item: $editing) { entry in DiaryEntryEditorMobileView(initial: entry, initialDate: date, products: products, recipes: recipes) { await onChanged() } }
    }

    private func diaryDayStat(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption2).foregroundStyle(AstraTheme.muted); Text(value).font(.headline.weight(.bold)) }.frame(maxWidth: .infinity, alignment: .leading) }
    private func delete(_ entry: DiaryEntry) { Task { do { _ = try await session.api.deleteDiary(id: entry.id); await onChanged() } catch {} } }
}

struct DiaryFoodPickerMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let date: String; let products: [Product]; let recipes: [Recipe]; let onSaved: () async -> Void
    @State private var search = ""
    @State private var tab = "Блюда"
    private let tabs = ["Блюда", "Продукты", "Новое", "Все"]
    private var filteredRecipes: [Recipe] { recipes.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    private var filteredProducts: [Product] { products.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) { Image(systemName: "magnifyingglass").foregroundStyle(AstraTheme.blue); TextField("Поиск", text: $search).textFieldStyle(.plain) }.padding(.horizontal, 16).frame(height: 42).background(AstraTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(AstraTheme.line, lineWidth: 1))
                    HStack(spacing: 8) { ForEach(tabs, id: \.self) { item in if item == "Новое" { NavigationLink { DiaryEntryEditorMobileView(initial: nil, initialDate: date, products: products, recipes: recipes, presetKind: "custom", onSaved: onSaved) } label: { diaryPickerPill(item, active: false) }.buttonStyle(.plain) } else { Button { tab = item } label: { diaryPickerPill(item, active: tab == item) }.buttonStyle(.plain) } } }
                    HStack(alignment: .top) { VStack(alignment: .leading, spacing: 3) { Text("Выберите запись").font(.headline); Text("Нажмите на карточку, чтобы указать количество").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Button("Отмена") { dismiss() }.font(.caption.weight(.bold)) }
                    if tab == "Блюда" || tab == "Все" { ForEach(filteredRecipes) { recipe in NavigationLink { DiaryEntryEditorMobileView(initial: nil, initialDate: date, products: products, recipes: recipes, presetRecipeID: recipe.id, onSaved: onSaved) } label: { diaryPickerCard(icon: "fork.knife.circle.fill", title: recipe.name, detail: "\(recipe.category) · \(recipe.kcalPerServing.display) ккал · Б \(recipe.proteinPerServingG.display) г", color: AstraTheme.blue) }.buttonStyle(.plain) } }
                    if tab == "Продукты" || tab == "Все" { ForEach(filteredProducts) { product in NavigationLink { DiaryEntryEditorMobileView(initial: nil, initialDate: date, products: products, recipes: recipes, presetProductID: product.id, onSaved: onSaved) } label: { diaryPickerCard(icon: "carrot.fill", title: product.name, detail: "\(product.category ?? "Без категории") · \(product.kcal.display) ккал · Б \(product.proteinG.display) г", color: AstraTheme.blue) }.buttonStyle(.plain) } }
                }
                .padding(20)
            }
            .background(AstraTheme.canvas)
            .navigationTitle("Добавить в дневник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
    }

    private func diaryPickerPill(_ title: String, active: Bool) -> some View { Text(title).font(.caption.weight(.semibold)).foregroundStyle(active ? AstraTheme.blue : AstraTheme.ink).frame(maxWidth: .infinity).frame(height: 28).background(active ? AstraTheme.blue.opacity(0.12) : AstraTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(active ? AstraTheme.blue : AstraTheme.line, lineWidth: 1)) }
    private func diaryPickerCard(icon: String, title: String, detail: String, color: Color) -> some View { AstraCard { HStack(spacing: 12) { Image(systemName: icon).font(.title3).foregroundStyle(color); VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AstraTheme.ink); Text(detail).font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(color).frame(width: 28, height: 28).background(color.opacity(0.12)).clipShape(Circle()) } } }
}

struct DiaryEntryEditorMobileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let initial: DiaryEntry?; let initialDate: String; let products: [Product]; let recipes: [Recipe]; let presetKind: String?; let presetProductID: Int?; let presetRecipeID: Int?; let onSaved: () async -> Void
    @State private var kind: String; @State private var date: String; @State private var meal: String; @State private var productID: Int; @State private var recipeID: Int; @State private var amount: String; @State private var unit: String; @State private var comment: String; @State private var customName = ""; @State private var customKcal = ""; @State private var customProtein = ""; @State private var customFat = ""; @State private var customCarbs = ""; @State private var error: String?; @State private var saving = false

    init(initial: DiaryEntry?, initialDate: String, products: [Product], recipes: [Recipe], presetKind: String? = nil, presetProductID: Int? = nil, presetRecipeID: Int? = nil, onSaved: @escaping () async -> Void) { self.initial = initial; self.initialDate = initialDate; self.products = products; self.recipes = recipes; self.presetKind = presetKind; self.presetProductID = presetProductID; self.presetRecipeID = presetRecipeID; self.onSaved = onSaved; _kind = State(initialValue: presetKind ?? (initial?.itemType == "product" ? "product" : "recipe")); _date = State(initialValue: initial?.entryDate ?? initialDate); _meal = State(initialValue: initial?.mealType ?? diaryMealOrderMobile[0]); _productID = State(initialValue: initial?.productId ?? presetProductID ?? products.first?.id ?? 0); _recipeID = State(initialValue: initial?.recipeId ?? presetRecipeID ?? recipes.first?.id ?? 0); _amount = State(initialValue: mobileDiaryNumber(initial?.measurementQuantity ?? initial?.quantity ?? initial?.servings ?? 1)); _unit = State(initialValue: initial?.measurementName ?? initial?.unit ?? products.first?.unit ?? "г"); _comment = State(initialValue: initial?.comment ?? "") }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип", selection: $kind) { Text("Продукт").tag("product"); Text("Блюдо").tag("recipe"); if initial == nil { Text("Новое блюдо").tag("custom") } }.pickerStyle(.segmented)
                TextField("Дата YYYY-MM-DD", text: $date)
                Picker("Приём пищи", selection: $meal) { ForEach(diaryMealOrderMobile, id: \.self) { Text($0) } }
                if kind == "product" { Picker("Продукт", selection: $productID) { ForEach(products) { Text($0.name).tag($0.id) } }; TextField("Количество", text: $amount).keyboardType(.decimalPad); TextField("Единица", text: $unit) }
                else if kind == "recipe" { Picker("Блюдо", selection: $recipeID) { ForEach(recipes) { Text($0.name).tag($0.id) } }; TextField("Порций", text: $amount).keyboardType(.decimalPad) }
                else { Section("Новое блюдо") { TextField("Название", text: $customName); TextField("Ккал", text: $customKcal).keyboardType(.decimalPad); TextField("Белки, г", text: $customProtein).keyboardType(.decimalPad); TextField("Жиры, г", text: $customFat).keyboardType(.decimalPad); TextField("Углеводы, г", text: $customCarbs).keyboardType(.decimalPad); TextField("Порций", text: $amount).keyboardType(.decimalPad) } }
                TextField("Комментарий", text: $comment, axis: .vertical)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(initial == nil ? "Добавить запись" : "Редактировать запись")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Сохранение…" : "Сохранить") { save() }.disabled(saving) } }
        }
    }

    private func save() { saving = true; error = nil; let number = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 1; var values: [String: AnyEncodable] = ["entry_date": AnyEncodable(date), "meal_type": AnyEncodable(meal), "servings": AnyEncodable(kind == "product" ? 1 : number), "comment": editorOptionalString(comment)]; if kind == "product" { values["product_id"] = AnyEncodable(productID); values["quantity"] = AnyEncodable(number); values["measurement_quantity"] = AnyEncodable(number); values["measurement_name"] = AnyEncodable(unit) } else if kind == "recipe" { values["recipe_id"] = AnyEncodable(recipeID) } else { let custom = JSONPayload(values: ["name": AnyEncodable(customName), "kcal": editorOptionalNumber(customKcal), "protein_g": editorOptionalNumber(customProtein), "fat_g": editorOptionalNumber(customFat), "carbs_g": editorOptionalNumber(customCarbs)]); values["custom_dish"] = AnyEncodable(custom) }; let payload = JSONPayload(values: values); Task { do { if let id = initial?.id { _ = try await session.api.updateDiary(id: id, payload: payload) } else { _ = try await session.api.createDiary(payload) }; await onSaved(); dismiss() } catch { error = error.localizedDescription; saving = false } } }
}
