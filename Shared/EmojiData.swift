import Foundation

public struct EmojiCategory: Identifiable, Equatable {
    public let id: String
    public let icon: String
    public let name: String
    public let emoji: [String]
}

public enum EmojiData {
    public static let categories: [EmojiCategory] = [
        .init(id: "smileys", icon: "😀", name: "Smileys", emoji: "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😋 😛 😜 🤪 🤔 🤗 🤭 😐 😑 😶 🙄 😏 😬 😌 😔 😴 😷 🤒 🤕 🤢 🥵 🥶 😎 🤓 😕 😟 🙁 😮 😲 😳 🥺 😢 😭 😱 😖 😞 😤 😡 🤬 😈 💀 💩 🤡".split(separator: " ").map(String.init)),
        .init(id: "people", icon: "👍", name: "People", emoji: "👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🖐 🖖 👋 🤝 🙏 ✍️ 💪 👏 🙌 👐 🤲 🧠 👀 👁 👂 👃 👄 👶 👧 🧒 👦 👩 🧑 👨 👵 👴".split(separator: " ").map(String.init)),
        .init(id: "nature", icon: "🐶", name: "Animals & Nature", emoji: "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🦆 🦉 🐺 🐴 🦄 🐝 🦋 🐌 🐢 🐍 🐙 🐬 🐳 🦈 🌵 🌲 🌳 🌴 🌱 🌿 🍀 🌷 🌹 🌻 🌼 ☀️ ⭐ 🌙 ⛅ ☁️ 🌧 ⚡ ❄️ 🔥 🌈".split(separator: " ").map(String.init)),
        .init(id: "food", icon: "🍔", name: "Food & Drink", emoji: "🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🧀 🍳 🥞 🥓 🍔 🍟 🍕 🌭 🌮 🍣 🍜 🍝 🍦 🍩 🍪 🎂 🍰 🍫 🍿 ☕ 🍵 🍺 🍷 🥂 🍸".split(separator: " ").map(String.init)),
        .init(id: "activity", icon: "⚽", name: "Activities", emoji: "⚽ 🏀 🏈 ⚾ 🎾 🏐 🏉 🎱 🏓 🏸 🥊 ⛳ 🏆 🥇 🥈 🥉 🎮 🎲 🎯 🎨 🎬 🎤 🎧 🎸 🎹 🥁 🎻 🚴 🏊 🏃 🧘".split(separator: " ").map(String.init)),
        .init(id: "travel", icon: "🚗", name: "Travel & Places", emoji: "🚗 🚕 🚌 🚓 🚑 🚒 🚲 🏍 ✈️ 🚀 🚁 🚂 🚢 ⛵ 🏠 🏢 🏥 🏫 🏰 ⛪ 🗽 🗼 🌋 🏝 🏖 🌍 🌎 🌏 🗺 ⛰ 🏕".split(separator: " ").map(String.init)),
        .init(id: "objects", icon: "💡", name: "Objects", emoji: "⌚ 📱 💻 ⌨️ 🖥 📷 📺 📻 ⏰ 🔋 💡 🔦 💰 💳 🔑 🔒 🔨 🧰 📦 ✉️ 📝 📌 📎 📚 🎁 🎈 🔔 🧲 💊 🧸".split(separator: " ").map(String.init)),
        .init(id: "symbols", icon: "❤️", name: "Symbols", emoji: "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💯 ✅ ❌ ❓ ❗ ⚠️ ♻️ ➕ ➖ ✔️ ➡️ ⬅️ ⬆️ ⬇️ 🔴 🟢 🔵 ⚪ ⚫ ✨ 💫 💥 💢 💤 🎵".split(separator: " ").map(String.init)),
    ]
}

/// Most-recently-used emoji, persisted locally. Contains only emoji the user tapped (no text content).
public final class RecentEmojiStore {
    private static let key = "recentEmoji.v1"
    private let defaults: UserDefaults
    private let limit: Int
    public init(defaults: UserDefaults, limit: Int = 24) { self.defaults = defaults; self.limit = limit }
    public convenience init() { self.init(defaults: UserDefaults(suiteName: SettingsStore.appGroupID) ?? .standard) }
    public var recents: [String] { defaults.stringArray(forKey: Self.key) ?? [] }
    public func record(_ e: String) {
        var r = recents.filter { $0 != e }; r.insert(e, at: 0)
        defaults.set(Array(r.prefix(limit)), forKey: Self.key)
    }
    public func clear() { defaults.removeObject(forKey: Self.key) }
}
