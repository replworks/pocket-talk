import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScenarioRunnerView()
                .tabItem { Label("시나리오", systemImage: "list.bullet.rectangle") }
            ASRTestView()
                .tabItem { Label("ASR", systemImage: "mic") }
            LiveSessionView()
                .tabItem { Label("라이브", systemImage: "waveform") }
        }
    }
}

#Preview {
    RootView()
}
