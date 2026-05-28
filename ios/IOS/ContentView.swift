import SwiftUI

struct ContentView: View {
    @State private var selectedTab = "home"
    @State private var navigationPath = NavigationPath()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag("home")

                ScheduleView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Sailings")
                    }
                    .tag("schedule")

                BookView()
                    .tabItem {
                        Image(systemName: "ticket")
                        Text("Book")
                    }
                    .tag("book")

                MapView()
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text("Map")
                    }
                    .tag("map")

                WildlifeView()
                    .tabItem {
                        Image(systemName: "pawprint.fill")
                        Text("Wildlife")
                    }
                    .tag("wildlife")

                TicketsView()
                    .tabItem {
                        Image(systemName: "qrcode")
                        Text("Tickets")
                    }
                    .tag("tickets")

                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag("profile")

                AdminView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Admin")
                    }
                    .tag("admin")
            }
            .tint(Theme.sea)
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "book":
                    BookView()
                default:
                    EmptyView()
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
