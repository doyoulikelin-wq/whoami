import SwiftUI

@main
struct WhoAmIApp: App {
    @StateObject private var store = AppStore()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Palette.background)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.accent)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab = 0
    @State private var composing = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(onCompose: { composing = true }, onJournal: { selectedTab = 1 })
                    .toolbar { composeToolbar }
            }
            .tabItem { Label("今天", systemImage: "circle.dotted") }.tag(0)

            NavigationStack {
                JournalHomeView(onCompose: { composing = true })
                    .toolbar { composeToolbar }
            }
            .tabItem { Label("日记", systemImage: "book") }.tag(1)

            NavigationStack {
                ReviewHomeView().toolbar { composeToolbar }
            }
            .tabItem { Label("复盘", systemImage: "arrow.triangle.2.circlepath") }.tag(2)

            NavigationStack {
                ProfileHomeView().toolbar { composeToolbar }
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(3)
        }
        .sheet(isPresented: $composing) { ComposerView() }
        .alert("本地存储", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("知道了", role: .cancel) { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
    }

    @ToolbarContentBuilder
    private var composeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { composing = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 44, height: 44)
            }.accessibilityLabel("新增记录").accessibilityIdentifier("compose-toolbar")
        }
    }
}
