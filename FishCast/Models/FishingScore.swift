import Foundation

/// Actionable fishing forecast produced by ``FishingConditionsEngine``.
struct FishingScore: Sendable {
    let score: Int                         // 0 ... 100
    let rating: Rating
    let factors: [ConditionFactor]
    let summary: String

    enum Rating: String, Sendable {
        case excellent, good, fair, poor

        init(score: Int) {
            switch score {
            case 80...:    self = .excellent
            case 60...79:  self = .good
            case 40...59:  self = .fair
            default:       self = .poor
            }
        }

        var label: String {
            switch self {
            case .excellent: return "Excellent"
            case .good:      return "Good"
            case .fair:      return "Fair"
            case .poor:      return "Poor"
            }
        }
    }
}

struct ConditionFactor: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let impact: Impact
    let explanation: String

    enum Impact: Sendable {
        case positive, neutral, negative
    }
}
