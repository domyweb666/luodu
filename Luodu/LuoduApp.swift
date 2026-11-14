import SwiftUI

@main
struct LuoduApp: App {
    @State private var store: Store
    @State private var importer = BookImporter()

    init() {
        let store = Store()
        #if DEBUG
        DebugLaunch.importBookIfAsked(into: store)
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(importer)
        }
    }
}
