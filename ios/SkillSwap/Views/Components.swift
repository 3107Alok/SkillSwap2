import SwiftUI

// Small building blocks used by many screens.

enum Fmt {
    private static let plain = ISO8601DateFormatter()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM, h:mm a"
        return f
    }()

    static func parse(_ text: String?) -> Date? {
        guard let text = text else { return nil }
        return plain.date(from: text) ?? fractional.date(from: text)
    }

    static func when(_ text: String?) -> String {
        guard let date = parse(text) else { return "-" }
        return display.string(from: date)
    }

    static func iso(_ date: Date) -> String {
        plain.string(from: date)
    }

    static func percent(_ value: Double?) -> String {
        guard let value = value else { return "New" }
        return "\(Int((value * 100).rounded()))% reliable"
    }
}

/// The avatar picked automatically from the gender chosen in the profile (served by the backend).
struct AvatarView: View {
    let path: String
    var size: CGFloat = 44

    var body: some View {
        AsyncImage(url: URL(string: AppConfig.shared.baseURL + path)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundColor(.gray)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct ErrorBanner: View {
    let message: String?

    var body: some View {
        if let message = message, !message.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundColor(.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = .blue

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

func levelColor(_ level: String) -> Color {
    switch level {
    case "Trusted": return .green
    case "Contributor": return .blue
    default: return .gray
    }
}

func statusColor(_ status: String) -> Color {
    switch status {
    case "done": return .green
    case "missed", "abandoned": return .red
    case "excused": return .orange
    default: return .gray
    }
}

/// One person (or project) suggested by the matching engine, with the "why this match" line.
struct MatchCard: View {
    let item: MatchItem
    var showsPerson = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if showsPerson {
                    AvatarView(path: item.avatarUrl)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline)
                    if !item.needRole.isEmpty && !showsPerson {
                        Text("Role: \(item.needRole)").font(.subheadline).foregroundColor(.secondary)
                    }
                    if let domain = item.domain {
                        Text(domain).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(item.percent)%")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(item.percent >= 70 ? Color.green : (item.percent >= 45 ? Color.orange : Color.gray))
                    .clipShape(Capsule())
            }
            Text(item.why).font(.subheadline)
            if let standing = item.standing, standing.counted > 0 || standing.points > 0 {
                Text("\(standing.level) in \(standing.domain) · \(Fmt.percent(standing.reliability)) · \(standing.points) pts")
                    .font(.caption)
                    .foregroundColor(levelColor(standing.level))
            }
            ForEach(item.leaderTags, id: \.self) { tag in
                Pill(text: "Leader: \(tag)", color: .purple)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Runs an async action from a button and shows its error text. Keeps the views short.
func attempt(_ errorText: Binding<String?>, busy: Binding<Bool>? = nil, _ work: @escaping () async throws -> Void) {
    errorText.wrappedValue = nil
    busy?.wrappedValue = true
    Task { @MainActor in
        do {
            try await work()
        } catch {
            errorText.wrappedValue = error.localizedDescription
        }
        busy?.wrappedValue = false
    }
}
