import SwiftUI

@main
struct LuoduApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(store)
        }
    }
}
