import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("For you", systemImage: "sparkles") }
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "folder") }
            FindPeopleView()
                .tabItem { Label("Find people", systemImage: "person.2") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
