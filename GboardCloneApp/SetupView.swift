import SwiftUI

struct SetupView: View {
    @State private var testText = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Enable the keyboard") {
                    step(1, "Open Settings → General → Keyboard → Keyboards → Add New Keyboard…")
                    step(2, "Choose “RegBoard” under Third-Party Keyboards.")
                    step(3, "Optional: tap RegBoard, then turn on Allow Full Access (see below).")
                    step(4, "In any text field, press and hold 🌐 and choose RegBoard.")
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Try it") {
                    TextField("Tap here and switch to RegBoard", text: $testText, axis: .vertical).lineLimit(3...6)
                }
                Section("About Full Access") {
                    Text("RegBoard works without Full Access. Turning it on is only needed to (a) sync your settings from this app into the keyboard, and (b) allow haptic feedback. RegBoard contains no networking code, no analytics, and never sends anything off your device. However, iOS itself warns that a keyboard with Full Access *could* transmit what you type — that is a platform-level warning that applies to every keyboard.")
                        .font(.footnote)
                }
                Section("Good to know") {
                    Text("iOS shows the system keyboard in password fields and number pads; RegBoard cannot replace it there. iOS also does not let third-party keyboards use the microphone or the system emoji/dictation keys.")
                        .font(.footnote)
                }
            }
            .navigationTitle("RegBoard")
        }
    }
    private func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top) { Text("\(n).").bold().frame(width: 22, alignment: .leading); Text(t) }
    }
}
