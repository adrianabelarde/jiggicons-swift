// The README's examples, compiled so they keep working.
import SwiftUI
import Jiggicons

struct ReadmeSnippets: View {
    @State private var saved = 0

    var body: some View {
        VStack {
            JiggIcon("bell", variant: .solid, size: 28, sound: true, label: "Notifications")
            Button { saved += 1 } label: {
                Label { Text("Save") } icon: { JiggIcon("saved", variant: .duotone, trigger: .none, playWhen: saved) }
            }
            if let bell = Jiggicons.icon(named: "bell") {
                JiggiconFrame(icon: bell, variant: .glass, seconds: 0.2)
            }
        }
        .onAppear { JiggiconsAudio.shared.volume = 0.6 }
    }
}
