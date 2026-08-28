import SwiftUI

struct ContentView: View {
    @State private var schedule = ScheduleStore()
    @State private var settings = AppSettings()

    var body: some View {
        Group {
            if settings.hasSeenOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(schedule)
        .environment(settings)
        .task { await schedule.load() }
        .tint(Theme.sea)
    }
}

struct MainTabView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "ferry.fill") }

            ScheduleView()
                .tabItem { Label("Sailings", systemImage: "calendar") }

            BookView()
                .tabItem { Label("Book", systemImage: "ticket.fill") }

            MembershipView()
                .tabItem { Label("Member", systemImage: "crown.fill") }

            MoreView()
                .tabItem { Label("More", systemImage: "square.grid.2x2.fill") }
        }
        .fullScreenCover(isPresented: $settings.showAdmin) {
            AdminView()
        }
    }
}

#Preview {
    ContentView()
}
