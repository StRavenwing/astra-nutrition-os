import SwiftUI

struct MobileMainView: View {
    @State private var tab: AppTab = .overview

    var body: some View {
        TabView(selection: $tab) {
            DashboardMobileView(onNavigate: { tab = $0 })
                .tabItem { Label("Обзор", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.overview)
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "fork.knife") }
                .tag(AppTab.diary)
            FitnessWorkoutsView()
                .tabItem { Label("Тренировки", systemImage: "bolt.fill") }
                .tag(AppTab.workouts)
            TrainerView()
                .tabItem { Label("Тренер", systemImage: "person.2.fill") }
                .tag(AppTab.trainer)
            InformationView()
                .tabItem { Label("Инфо", systemImage: "info.circle.fill") }
                .tag(AppTab.information)
            CatalogMobileView()
                .tabItem { Label("Каталог", systemImage: "books.vertical.fill") }
                .tag(AppTab.catalog)
            ProgressScreen()
                .tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            MoreMobileView(tab: $tab)
                .tabItem { Label("Ещё", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.settings)
        }
        .tint(AstraTheme.blue)
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
                            dashboardTile("Одобренные рецепты", "\(dashboard.approved)", "checkmark.seal.fill", .orange) { onNavigate(.catalog) }
                            dashboardTile("Вес", dashboard.latest?.weightKg.display ?? "—", "chart.line.uptrend.xyaxis", .purple) { onNavigate(.progress) }
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

struct MoreMobileView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var tab: AppTab
    @AppStorage("astra_theme") private var theme = "light"
    @State private var showAPI = false
    @State private var apiURL = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Toggle("Тёмная тема", isOn: Binding(
                        get: { theme == "dark" },
                        set: { theme = $0 ? "dark" : "light" }
                    ))
                }
                Section("Каталоги веб-версии") {
                    Button { tab = .catalog } label: { Label("Продукты и рецепты", systemImage: "books.vertical.fill") }
                    Button { tab = .information } label: { Label("Статьи и информация", systemImage: "info.circle.fill") }
                }
                Section("Контроль") {
                    Button { tab = .progress } label: { Label("Замеры и цели", systemImage: "chart.line.uptrend.xyaxis") }
                    Button { tab = .workouts } label: { Label("Журнал тренировок", systemImage: "bolt.fill") }
                    Button { tab = .trainer } label: { Label("Чат с тренером", systemImage: "person.2.fill") }
                }
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
                }.presentationDetents([.medium])
            }
        }
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
    @State private var selectedRecipe: Recipe?
    @State private var error: String?

    private var productCategoryNames: [String] { ["Все"] + productCategories.map(\.name) }
    private var recipeCategoryNames: [String] { ["Все"] + recipeCategories.map(\.name) }
    private var filteredProducts: [Product] { products.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (category == "Все" || $0.category == category) } }
    private var filteredRecipes: [Recipe] { recipes.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (category == "Все" || $0.category == category) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Раздел", selection: $mode) { Text("Продукты").tag(0); Text("Рецепты").tag(1) }.pickerStyle(.segmented).padding()
                Picker("Категория", selection: $category) { ForEach(mode == 0 ? productCategoryNames : recipeCategoryNames, id: \.self) { Text($0).tag($0) } }.padding(.horizontal)
                if mode == 0 {
                    List(filteredProducts) { product in
                        HStack { Image(systemName: "carrot.fill").foregroundStyle(AstraTheme.green); VStack(alignment: .leading) { Text(product.name).font(.headline); Text("\(product.category ?? "Без категории") · \(product.kcal.display) ккал").font(.caption).foregroundStyle(AstraTheme.muted) }; Spacer(); Text("Б \(product.proteinG.display) г").font(.caption.weight(.bold)) }
                    }
                } else {
                    List(filteredRecipes) { recipe in Button { selectedRecipe = recipe } label: { RecipeRow(recipe: recipe) }.buttonStyle(.plain) }
                }
            }
            .searchable(text: $search, prompt: "Поиск в каталоге")
            .navigationTitle("Каталог")
            .onChange(of: mode) { _, _ in category = "Все" }
            .overlay { if products.isEmpty && recipes.isEmpty && error == nil { ProgressView() } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $selectedRecipe) { RecipeDetailView(recipe: $0) }
        }
    }

    private func load() async {
        do {
            async let p = session.api.products(); async let r = session.api.recipes(); async let pc = session.api.categories(kind: "product"); async let rc = session.api.categories(kind: "recipe")
            products = try await p; recipes = try await r; productCategories = try await pc; recipeCategories = try await rc; error = nil
        } catch { error = error.localizedDescription }
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
            TrainerWorkspaceFullView()
        } else {
            ClientTrainerView()
        }
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
                        HStack { Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(AstraTheme.blue); VStack(alignment: .leading) { Text(client.name).font(.headline); Text(client.email).font(.caption).foregroundStyle(AstraTheme.muted); if let next = client.nextWorkout { Text("Ближайшая тренировка: \(next.scheduledAt)").font(.caption2).foregroundStyle(AstraTheme.green) } }; Spacer(); if client.unreadMessages > 0 { Text("\(client.unreadMessages)").font(.caption.weight(.bold)).padding(7).background(.orange.opacity(0.18)).clipShape(Circle()) } }
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
            .sheet(item: $selectedExercise) { TrainerExerciseDetailView(exercise: $0) }
            .sheet(item: $selectedComplex) { TrainerComplexDetailView(complex: $0) }
            .sheet(item: $selectedEquipment) { TrainerEquipmentDetailView(item: $0) }
            .sheet(item: $selectedPlan) { TrainerPlanDetailView(plan: $0) }
            .sheet(item: $selectedWorkout) { TrainerWorkoutDetailView(workout: $0) }
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

struct TrainerExerciseDetailView: View { @Environment(\.dismiss) private var dismiss; let exercise: Exercise; var body: some View { NavigationStack { List { Section { Text(exercise.name).font(.title2.weight(.bold)); Text(exercise.muscleGroup ?? "Другое").foregroundStyle(AstraTheme.muted) }; Section("Рекомендации") { LabeledContent("Единица", value: exercise.defaultUnit ?? "—"); LabeledContent("Подходы", value: exercise.defaultSets.display); LabeledContent("Повторения", value: exercise.defaultReps.display) } }.navigationTitle("Упражнение").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerComplexDetailView: View { @Environment(\.dismiss) private var dismiss; let complex: WorkoutComplex; var body: some View { NavigationStack { List { Section { Text(complex.name).font(.title2.weight(.bold)); if let comment = complex.comment { Text(comment) } }; Section("Упражнения") { ForEach(complex.items) { item in VStack(alignment: .leading) { Text(item.name).font(.headline); Text("\(item.sets.display) подхода · \(item.durationMinutes.display) мин").font(.caption).foregroundStyle(AstraTheme.muted) } } } }.navigationTitle("Комплекс").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerEquipmentDetailView: View { @Environment(\.dismiss) private var dismiss; let item: WorkoutEquipment; var body: some View { NavigationStack { List { Text(item.name).font(.title2.weight(.bold)); LabeledContent("Тип", value: item.kind == "machine" ? "Тренажёр" : "Инвентарь"); if let description = item.description { Text(description) } }.navigationTitle("Справочник").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerPlanDetailView: View { @Environment(\.dismiss) private var dismiss; let plan: WorkoutPlan; var body: some View { NavigationStack { List { Section { Text(plan.scheduledAt).font(.title2.weight(.bold)); Text(plan.status).foregroundStyle(AstraTheme.muted) }; Section("Упражнения") { ForEach(plan.items) { item in VStack(alignment: .leading) { Text(item.name ?? "Упражнение").font(.headline); Text("\(item.sets.display) подхода · \(item.durationMinutes.display) мин").font(.caption).foregroundStyle(AstraTheme.muted) } } } }.navigationTitle("План").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }
struct TrainerWorkoutDetailView: View { @Environment(\.dismiss) private var dismiss; let workout: WorkoutEntry; var body: some View { NavigationStack { List { Text(workout.name).font(.title2.weight(.bold)); LabeledContent("Дата", value: workout.performedAt); LabeledContent("Подходы", value: workout.sets.display); LabeledContent("Повторения", value: workout.reps.display); LabeledContent("Вес", value: workout.workingWeight.display); if let comment = workout.comment { Text(comment) } }.navigationTitle("История").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } } }

struct InformationView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var sections: [ArticleSection] = []
    @State private var articles: [Article] = []
    @State private var selectedSection: Int?
    @State private var search = ""
    @State private var selectedArticle: Article?
    @State private var error: String?

    private var filtered: [Article] { articles.filter { (selectedSection == nil || $0.sectionId == selectedSection) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) || ($0.tags ?? "").localizedCaseInsensitiveContains(search)) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Header(title: "Информация", subtitle: "Питание, тренировки и полезные материалы")
                    ScrollView(.horizontal, showsIndicators: false) { HStack { sectionChip("Все", nil); ForEach(sections) { section in sectionChip(section.name, section.id) } }.padding(.vertical, 2) }
                    if let error { Text(error).foregroundStyle(.red) }
                    if filtered.isEmpty && error == nil { EmptyState(title: "Статей пока нет", message: "Материалы появятся здесь после публикации в веб-версии.", icon: "text.book.closed") }
                    ForEach(filtered) { article in
                        Button { selectedArticle = article } label: {
                            AstraCard { VStack(alignment: .leading, spacing: 7) { HStack { Text(article.sectionName.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.blue); Spacer(); if article.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) } }; Text(article.title).font(.headline).foregroundStyle(AstraTheme.ink); Text(article.body.plainText).lineLimit(3).font(.subheadline).foregroundStyle(AstraTheme.muted) } }
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }.background(AstraTheme.canvas).searchable(text: $search, prompt: "Найти статью").navigationTitle("Информация").task { await load() }.refreshable { await load() }.sheet(item: $selectedArticle) { ArticleDetailMobileView(article: $0) }
        }
    }

    @ViewBuilder private func sectionChip(_ title: String, _ id: Int?) -> some View { Button(title) { selectedSection = id }.buttonStyle(.borderedProminent).tint(selectedSection == id ? AstraTheme.blue : AstraTheme.muted.opacity(0.25)).foregroundStyle(selectedSection == id ? .white : AstraTheme.ink) }
    private func load() async { do { async let s = session.api.articleSections(); async let a = session.api.articles(); sections = try await s; articles = try await a; error = nil } catch { error = error.localizedDescription } }
}

struct ArticleDetailMobileView: View {
    @Environment(\.dismiss) private var dismiss
    let article: Article
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 14) { Text(article.sectionName.uppercased()).font(.caption.weight(.bold)).foregroundStyle(AstraTheme.blue); Text(article.title).font(.title2.weight(.bold)); Text(article.body.plainText).font(.body); if let tags = article.tags { Text(tags).font(.caption).foregroundStyle(AstraTheme.muted) }; ForEach(article.links, id: \.url) { link in Link(link.title, destination: URL(string: link.url)!) } }.padding() }.navigationTitle("Статья").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
    }
}

private extension String { var plainText: String { replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression).replacingOccurrences(of: "&nbsp;", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) } }

struct FitnessWorkoutsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var section = 0
    @State private var plans: [WorkoutPlan] = []
    @State private var logs: [WorkoutEntry] = []
    @State private var exercises: [Exercise] = []
    @State private var complexes: [WorkoutComplex] = []
    @State private var equipment: [WorkoutEquipment] = []
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
                            Section("Журнал") { ForEach(logs) { log in VStack(alignment: .leading) { Text(log.name).font(.headline); Text("\(log.performedAt) · \(log.sets.display) подходов × \(log.reps.display) повторений").font(.caption).foregroundStyle(AstraTheme.muted) } } }
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
        }
    }

    private func load() async {
        do { async let p = session.api.workoutPlans(); async let l = session.api.workouts(); async let e = session.api.exercises(); async let c = session.api.workoutComplexes(); async let i = session.api.workoutEquipment(); plans = try await p; logs = try await l; exercises = try await e; complexes = try await c; equipment = try await i; error = nil }
        catch { error = error.localizedDescription }
    }

    private func complete(_ plan: WorkoutPlan) { Task { do { _ = try await session.api.completeWorkoutPlan(id: plan.id); await load() } catch { error = error.localizedDescription } } }
}
