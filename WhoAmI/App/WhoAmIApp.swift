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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("总览", systemImage: "square.grid.2x2") }.tag(0)
            NavigationStack { DimensionRecordView() }
                .tabItem { Label("记录", systemImage: "circle.dotted") }.tag(1)
            NavigationStack { ComparisonView() }
                .tabItem { Label("对比", systemImage: "rectangle.split.2x1") }.tag(2)
        }
        .alert("本地存储", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("知道了", role: .cancel) { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
    }
}
