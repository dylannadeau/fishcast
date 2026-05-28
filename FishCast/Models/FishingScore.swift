import Foundation

/// Actionable fishing forecast produced by ``FishingConditionsEngine``.
///
/// Two naming conventions live side-by-side here: the historical short names
/// (`score`, `summary`, `factors`) that view code already binds to, and the
/// longer names from the species-aware spec (`overallScore`, `summaryText`,
/// `conditionFactors`). They're computed aliases of the same storage so
/// existing callers don't need to change.
struct FishingScore: Sendable {
    let score: Int                         // 0 ... 100
    let rating: Rating
    let factors: [ConditionFactor]
    let summary: String

    /// Top 3 species predictions ranked by per-species likelihood, with
    /// situational tips. Empty if no target species were supplied.
    let topSpecies: [SpeciesPrediction]

    /// Next contiguous window (≥2 hrs) where the score is projected to
    /// reach 65+. `nil` when the current score is already good, or when
    /// no hourly forecast was supplied to the engine.
    let nextBestWindow: DateInterval?

    /// Plain-English explanation surfaced only when `score < 40`.
    let avoidReason: String?

    // MARK: Spec-spelled aliases

    var overallScore: Int { score }
    var summaryText: String { summary }
    var conditionFactors: [ConditionFactor] { factors }

    init(
        score: Int,
        rating: Rating,
        factors: [ConditionFactor],
        summary: String,
        topSpecies: [SpeciesPrediction] = [],
        nextBestWindow: DateInterval? = nil,
        avoidReason: String? = nil
    ) {
        self.score = score
        self.rating = rating
        self.factors = factors
        self.summary = summary
        self.topSpecies = topSpecies
        self.nextBestWindow = nextBestWindow
        self.avoidReason = avoidReason
    }

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
    /// Contribution this factor made to the overall score (+/-). Surfaced
    /// so the UI can show "biggest positive driver" style annotations
    /// without re-implementing the engine's math.
    let delta: Int

    enum Impact: Sendable {
        case positive, neutral, negative
    }

    init(name: String, impact: Impact, explanation: String, delta: Int = 0) {
        self.name = name
        self.impact = impact
        self.explanation = explanation
        self.delta = delta
    }
}
