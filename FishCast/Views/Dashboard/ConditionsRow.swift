import SwiftUI

/// Horizontal scroll of condition chips. The Dashboard rebuild expanded the
/// set: temperature, pressure (numeric), trend label (worded), wind,
/// humidity, cloud cover, precipitation chance.
struct ConditionsRow: View {
    let current: CurrentWeather
    let trend: PressureTrend

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ConditionChip(
                    icon: AppIcons.temperature,
                    value: tempValue,
                    unit: "°F Air"
                )

                PressureChip(pressure: current.pressure, trend: trend)

                TrendLabelChip(trend: trend)

                ConditionChip(
                    icon: AppIcons.wind,
                    value: windValue,
                    unit: "mph \(compassPoint(current.windDirection))"
                )

                ConditionChip(
                    icon: "humidity.fill",
                    value: "\(Int((current.humidity * 100).rounded()))%",
                    unit: "Humidity"
                )

                ConditionChip(
                    icon: cloudIcon,
                    value: cloudCoverLabel,
                    unit: "Sky"
                )

                ConditionChip(
                    icon: "cloud.rain.fill",
                    value: "\(Int((current.precipitationChance * 100).rounded()))%",
                    unit: "Precip"
                )
            }
            .padding(.horizontal, Layout.screenEdge)
        }
    }

    private var windValue: String {
        "\(Int(current.windSpeed.converted(to: .milesPerHour).value.rounded()))"
    }

    private var tempValue: String {
        "\(Int(current.temperature.converted(to: .fahrenheit).value.rounded()))°"
    }

    /// Crude cloud-cover string derived from WeatherKit's `condition`
    /// description — useful for the chip until we wire in an explicit
    /// percentage field.
    private var cloudCoverLabel: String {
        let s = current.conditionDescription.lowercased()
        if s.contains("partly cloudy") || s.contains("mostly clear") { return "Partly" }
        if s.contains("mostly cloudy") { return "Mostly" }
        if s.contains("overcast") || s.contains("foggy") { return "Overcast" }
        if s.contains("cloudy") { return "Cloudy" }
        if s.contains("clear") || s.contains("sunny") || s.contains("fair") { return "Clear" }
        return "—"
    }

    private var cloudIcon: String {
        let s = current.conditionDescription.lowercased()
        if s.contains("clear") || s.contains("sunny") || s.contains("fair") {
            return "sun.max.fill"
        }
        if s.contains("overcast") || s.contains("mostly cloudy") {
            return "cloud.fill"
        }
        return "cloud.sun.fill"
    }

    private func compassPoint(_ direction: Measurement<UnitAngle>) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let degrees = direction.converted(to: .degrees).value
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 45).rounded()) % points.count
        return points[index]
    }
}

/// Pressure-specific chip — numeric pressure value + trend arrow.
struct PressureChip: View {
    let pressure: Measurement<UnitPressure>
    let trend: PressureTrend

    private var hPa: Int {
        Int(pressure.converted(to: .hectopascals).value.rounded())
    }

    private var trendColor: Color {
        switch trend {
        case .rapidRise, .rapidFall: return .scorePoor
        case .slowRise:              return .scoreExcellent
        case .slowFall:              return .scoreFair
        case .steady:                return .textSecondary
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: AppIcons.barometer)
                .font(.system(size: IconSize.card))
                .foregroundStyle(Color.accentGold)

            HStack(spacing: 4) {
                Text("\(hPa)")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: trend.symbolName)
                    .font(.caption)
                    .foregroundStyle(trendColor)
            }

            Text("mb")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(width: 90)
        .padding(.vertical, Spacing.sm)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressure \(hPa) mb, \(trend.description)")
    }
}

/// Worded summary of the current pressure trend (e.g. "Falling Fast").
struct TrendLabelChip: View {
    let trend: PressureTrend

    private var label: String {
        switch trend {
        case .rapidRise: return "Rising Fast"
        case .slowRise:  return "Rising Slow"
        case .steady:    return "Steady"
        case .slowFall:  return "Falling Slow"
        case .rapidFall: return "Falling Fast"
        }
    }

    private var color: Color {
        switch trend {
        case .rapidFall: return .scoreExcellent
        case .slowFall:  return .scoreGood
        case .steady:    return .accentTeal
        case .slowRise:  return .scoreFair
        case .rapidRise: return .scorePoor
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: trend.symbolName)
                .font(.system(size: IconSize.card))
                .foregroundStyle(color)

            Text(label)
                .font(.appCallout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("Trend")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(width: 100)
        .padding(.vertical, Spacing.sm)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressure trend: \(trend.description)")
    }
}
