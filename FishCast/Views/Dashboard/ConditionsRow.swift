import SwiftUI

/// Horizontal scroll of condition chips: pressure, wind, temp, humidity, precip.
struct ConditionsRow: View {
    let current: CurrentWeather
    let trend: PressureTrend

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                PressureChip(pressure: current.pressure, trend: trend)

                ConditionChip(
                    icon: AppIcons.wind,
                    value: windValue,
                    unit: "mph \(compassPoint(current.windDirection))"
                )

                ConditionChip(
                    icon: AppIcons.temperature,
                    value: tempValue,
                    unit: "°F"
                )

                ConditionChip(
                    icon: "humidity.fill",
                    value: "\(Int((current.humidity * 100).rounded()))%",
                    unit: "Humidity"
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

    private func compassPoint(_ direction: Measurement<UnitAngle>) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let degrees = direction.converted(to: .degrees).value
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 45).rounded()) % points.count
        return points[index]
    }
}

/// Pressure-specific chip — value + trend arrow inline with the reading.
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

            Text("hPa")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(width: 90)
        .padding(.vertical, Spacing.sm)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressure \(hPa) hPa, \(trend.description)")
    }
}
