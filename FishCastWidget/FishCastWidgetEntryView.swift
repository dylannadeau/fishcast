import SwiftUI
import WidgetKit

struct FishCastWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FishCastTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidget(snapshot: entry.snapshot)
        default:
            MediumWidget(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small

private struct SmallWidget: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Spacer()
                    if let location = snapshot.locationName {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(snapshot.score)")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                Text(snapshot.rating.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(scoreColor(for: snapshot.score))
            }
            .padding(12)
        }
    }
}

// MARK: - Medium

private struct MediumWidget: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            backgroundGradient

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(snapshot.rating.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(scoreColor(for: snapshot.score))
                }
                .frame(width: 110, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.yellow)
                        Text(snapshot.locationName ?? "FishCast")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    if let factor = snapshot.topFactor {
                        Label(factor, systemImage: "arrow.up.right.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    if let hour = snapshot.bestHour, let hourScore = snapshot.bestHourScore {
                        Label("Best: \(formatHour(hour)) (\(hourScore))", systemImage: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Shared

private var backgroundGradient: some View {
    LinearGradient(
        colors: [Color(red: 0.04, green: 0.09, blue: 0.16),
                 Color(red: 0.07, green: 0.14, blue: 0.25)],
        startPoint: .top,
        endPoint: .bottom
    )
}

private func scoreColor(for score: Int) -> Color {
    switch score {
    case 80...:    return Color(red: 0.30, green: 0.69, blue: 0.31)
    case 60 ..< 80: return Color(red: 0.55, green: 0.76, blue: 0.29)
    case 40 ..< 60: return Color(red: 1.00, green: 0.76, blue: 0.03)
    default:       return Color(red: 0.96, green: 0.26, blue: 0.21)
    }
}

private func formatHour(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h a"
    var components = DateComponents()
    components.hour = hour
    let date = Calendar.current.date(from: components) ?? .now
    return formatter.string(from: date)
}
