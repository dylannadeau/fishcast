# Fishing Conditions Scoring — Specification

The canonical reference for what `FishingConditionsEngine` does and why. Read this before changing any weight, threshold, or species value. The engine itself lives in `FishCast/Services/FishingConditionsEngine.swift`; the species database in `FishCast/Models/TargetSpecies.swift`.

The engine is **stateless and pure**: same inputs → same outputs. No I/O. No singletons accessed. This is intentional — the scoring model is the heart of the product, and it has to stay testable and reproducible.

---

## Inputs

```swift
FishingConditionsEngine.computeScore(
    weather:       CurrentWeather,
    trend:         PressureTrend,
    date:          Date,
    targetSpecies: [TargetSpecies] = .allCases,
    hourlyForecast: [HourlyForecast] = [],
    moonInfo:      MoonInfo? = nil,
    sunrise:       Date? = nil,
    sunset:        Date? = nil,
    recentPrecipitation: Bool = false
) -> FishingScore
```

The optional inputs (`hourlyForecast`, `moonInfo`, `sunrise`/`sunset`) gracefully degrade — the engine falls back to clock-time heuristics when not provided. Callers that have the data should pass it in for sharper scoring.

## Output

```swift
struct FishingScore {
    score: Int                       // 0–100, clamped
    rating: .excellent | .good | .fair | .poor
    factors: [ConditionFactor]       // one per scoring factor, with delta
    summary: String                  // plain-English, top-factor driven
    topSpecies: [SpeciesPrediction]  // top 3, ranked
    nextBestWindow: DateInterval?    // populated only when score < 60
    avoidReason: String?             // populated only when score < 40
}
```

`overallScore`, `summaryText`, `conditionFactors` are computed aliases — back-compat with view code that bound to the original names.

---

## Scoring factors

Seven factors. Positive maxes sum to 100; penalties pull the raw total negative before clamping. Order below matches the engine.

### 1. Barometric pressure trend — 25 pts max (most important)

Fish swim bladders respond to atmospheric pressure changes. Physoclistous fish (closed bladder — bass, walleye, perch, panfish, pickerel) need **24–48 hours** to equalize. Physostomous fish (open bladder w/ pneumatic duct — trout, pike, catfish) vent gas in minutes.

| Trend (over 3h) | Δ inHg/hr | Points | Why |
|---|---|---:|---|
| `rapidFall` | > 0.06 | **+25** | Pre-storm feeding frenzy — fish eat aggressively before the front |
| `slowFall`  | 0.02–0.06 | **+20** | Steady, reliable bite |
| `steady`    | < 0.02 | **+15** | Predictable feeding |
| `slowRise`  | 0.02–0.06 | **+8**  | Fish adjusting; physostomous still active |
| `rapidRise` | > 0.06 | **+3**  | Physoclistous fish lethargic — bladder compressed, sinking to bottom |

Trend buckets are computed by `BarometricService` from a rolling 3h `UserDefaults` cache.

### 2. Absolute pressure — ±5 pts

Bonus or penalty on top of the trend factor. Only fires if pressure is in one of the extremes.

| Range (inHg) | Range (mb) | Points | Why |
|---|---|---:|---|
| 29.80–30.20 | 1009–1023 | **+5** | Ideal stable band |
| < 29.60 | < 1002 | **−5** | Storm-front lockup |
| > 30.50 | > 1033 | **−5** | High-pressure lockjaw |

### 3. Air temperature — 20 pts max (+3 seasonal bonus)

The engine takes the **weighted-average optimal range** of the target species set (peak + tolerance, averaged across `targetSpecies`). Score against that synthesized target:

| Where current temp falls | Points |
|---|---:|
| Inside averaged **peak** range | **+20** |
| Inside averaged **tolerance** range | **+12** |
| Within 5°F of tolerance | **+6** |
| > 10°F outside tolerance | **0** |
| Other (5–10°F outside) | **+3** |

**Seasonal trend bonus (+3):**
- Spring + temp ≥ tolerance lower bound: warming = fish on the feed
- Fall + temp ≤ peak upper bound: cooling = pre-winter feeding push

The seasonal bonus is *additive* — it stacks with the base temperature points.

### 4. Time of day / solunar — 20 pts max

Golden hour and solunar windows are the most reliable feeding triggers across temperate freshwater species.

| Condition | Points |
|---|---:|
| Golden hour + solunar major overlap | **+20** + flagged "Peak Feeding Window" |
| Golden hour (±1h around sunrise/sunset) | **+20** |
| Solunar major (moon overhead/underfoot, ±1h) | **+15** |
| Solunar minor (moonrise/moonset, ±30m) | **+10** |

**Modifiers (stack on the above):**
- Midday (10am–2pm) in summer: **−5**
- Night under full moon: **+8** (bass, walleye stay on the prowl)
- Night under new moon: **+3**

If `sunrise`/`sunset` aren't provided, fallback heuristic: hours 5–7 + 18–20 = golden hour.

Solunar requires `MoonInfo` with rise/set times. Without it, the solunar buckets are skipped.

### 5. Moon phase — 10 pts max

Lunar tidal pull moves bait and triggers feeding rhythms even on landlocked water.

| Phase | Points |
|---|---:|
| New / Full | **+10** |
| Waxing / Waning Gibbous | **+7** |
| First / Last Quarter | **+5** |
| Waxing / Waning Crescent | **+3** |
| (no `MoonInfo` provided) | **+5** (neutral) |

### 6. Wind — 10 pts max

| Wind (mph) | Points | Why |
|---|---:|---|
| 0–8 | **+10** | Calm — clean presentations |
| 8–15 | **+7** | "Walleye chop" — productive |
| 15–20 | **+4** | Workable but tough |
| 20–25 | **+1** | Fish push to leeward shelter |
| 25+ | **0** | Unsafe; fish go deep |

### 7. Cloud cover — 8 pts max

Derived from `CurrentWeather.conditionDescription` (WeatherKit doesn't surface a percent).

| Bucket | Source phrases | Points |
|---|---|---:|
| Partly | "partly cloudy", "mostly clear" | **+8** |
| Overcast | "mostly cloudy", "cloudy" | **+6** |
| Full overcast | "overcast", "foggy" | **+4** |
| Clear | "clear", "sunny", "fair" | **+2** |
| Unknown | (anything else) | **+3** |

### 8. Precipitation — 7 pts max

Same trick — bucketed off the condition description plus precipitation chance.

| Bucket | Points |
|---|---:|
| Light rain (drizzle, light rain) | **+7** |
| Moderate (rain with chance > 0.6, generic "shower") | **+3** |
| Heavy (heavy rain, thunder, storm, downpour) | **0** |
| None, but cleared in last 3h (`recentPrecipitation: true`) | **+5** |
| None, stable dry | **+5** |

---

## Species ranking

For each species in `targetSpecies`, start from the clamped overall environmental score and adjust:

1. **Bladder-driven pressure modifier:**
   - `rapidRise`: physoclistous −15, physostomous −5
   - `rapidFall`: physostomous +3 (extra reward — they recover faster), physoclistous unchanged

2. **Temperature fit:**
   - In species' peak range: **+5**
   - In tolerance range: **0**
   - Outside: **−10**

3. **Peak season:** if current season ∈ `peakSeasons`, **+10**

4. **Behavioural time-of-day bonus** (`behaviouralTimeBonus`):
   - Walleye, Yellow Perch: dawn/dusk **+5** (tapetum lucidum vision)
   - Largemouth/Smallmouth Bass: dawn **+5**; bright midday **−5**
   - Brook/Brown/Rainbow/Lake Trout: overcast or light rain **+5**
   - Channel Catfish: night **+5**
   - Black Crappie: dawn/dusk/overcast **+5**
   - Northern Pike, Chain Pickerel, Bluegill: **0**

5. **Species-specific temperature ceilings:**
   - Trout (all four) above 70°F: capped at 30% of computed score (thermal stress)
   - Largemouth/Smallmouth Bass, Crappie, Bluegill below 40°F: capped at 20% (cold lockup)

Clamp to 0…100, sort descending, slice top 3 into `FishingScore.topSpecies`. Full ranking is available via `FishingConditionsEngine.allSpeciesPredictions(...)` for the detail view.

Tips per species per condition live in `tip(for:context:)` — adapt to season + pressure trend.

---

## Species database

Defined in `Models/TargetSpecies.swift`. Temperature ranges are degrees Fahrenheit; "tolerance" is the broader feeding window, "peak" sits inside it.

| Species | Bladder | Tolerance °F | Peak °F | Peak Seasons |
|---|---|---:|---:|---|
| Largemouth Bass | physoclistous | 65–85 | 68–78 | spring, summer |
| Smallmouth Bass | physoclistous | 60–75 | 65–72 | spring, fall |
| Brook Trout | physostomous | 45–65 | 52–60 | spring, fall |
| Brown Trout | physostomous | 50–68 | 56–65 | spring, fall |
| Rainbow Trout | physostomous | 52–68 | 60–65 | spring, fall |
| Lake Trout | physostomous | 40–58 | 46–55 | spring, fall |
| Walleye | physoclistous | 55–72 | 62–68 | spring, fall |
| Yellow Perch | physoclistous | 58–72 | 65–70 | spring, fall |
| Chain Pickerel | physoclistous | 55–75 | 60–70 | spring, fall, winter |
| Northern Pike | physostomous | 50–70 | 55–65 | spring, fall |
| Black Crappie | physoclistous | 62–75 | 68–72 | spring |
| Bluegill | physoclistous | 65–80 | 70–75 | spring, summer |
| Channel Catfish | physostomous | 72–86 | 78–84 | summer, fall |

**Citations** (HSI publications — USFWS Habitat Suitability Index series unless noted):
- Largemouth Bass: Stuber et al. (1982)
- Brown / Rainbow Trout: Raleigh et al.
- Walleye: Hokanson (1977)
- Northern Pike: Casselman (1978)
- Channel Catfish: Brown et al.
- Black Crappie: Edwards et al.
- Yellow Perch: Krieger et al.

---

## Next-best-window projection

Triggered only when current `score < 60`. Algorithm (`nextBestWindow(context:hourly:)`):

1. Score each hour of the next 48h with `simplifiedHourlyScore` — same factor model as the full engine but reuses constant moon info and decays the pressure trend's influence linearly over 24h (trend persistence assumption).
2. Find the first **contiguous block of ≥2 hours** where the simplified score ≥ 65.
3. If no block qualifies, fall back to the **single highest-scoring hour** within 48h.
4. Format human-readable via `formatWindow` — "today from 6:15 AM to 8:30 AM", "tomorrow from …", "on Wednesday from …".

Caller must supply `hourlyForecast` for this to work. With no hourly data, `nextBestWindow` is `nil`.

---

## Whole-day species outlook (spot cards)

`daySpeciesOutlook(weather:trend:now:hourlyForecast:targetSpecies:moonInfo:sunrise:sunset:)` answers "which species are most/least likely **today**" for the Dashboard's per-spot cards. It does *not* introduce new factor math — it re-runs the existing pipeline at multiple sample times and averages:

1. Sample points: **now**, plus the **dawn window** (sunrise + 30 min) and **dusk window** (sunset − 1 h) when those are still ahead of us today. Light-change windows are the day's likelihood peaks, so a day-level answer must include them.
2. Each future sample synthesizes conditions from the nearest hourly forecast (temp, wind, precip, sky, pressure); humidity/UV/visibility carry over from current conditions since hourly forecasts don't include them.
3. Per-species likelihood = **mean across samples** (integer division). Tips come from the "now" sample.
4. The pressure trend is assumed to persist across today's samples.

The Dashboard slices the sorted result: top 3 → "Most likely", bottom 3 → "Least likely".

### Per-spot pressure trend

Spot cards derive the trend from **WeatherKit hourly history at the spot's own coordinates** rather than the device-location `BarometricService` cache: current pressure minus the reading nearest to (now − 3 h), classified by `PressureTrend.fromThreeHourDelta(hPa:)` — the same |Δ| ≤ 1 / ≤ 3 / > 3 hPa thresholds `BarometricService` uses. If no history reading lands within ±2 h of the 3-hours-ago mark, the trend falls back to `steady`.

Day-over-day forecast pressure deltas on the outlook strip span 24 h, not 3 h, so their rapid/slow thresholds are scaled ×2 (steady ≤ 2 hPa, rapid > 6 hPa — see `dailyTrend(fromDelta:)` in `FishingSpot.swift`).

---

## Summary text generation

`buildSummary(score:rating:factors:context:nextWindow:)` picks a lead sentence from the top-impact factor and tails it with an outlook based on the rating bucket:

- Excellent: "This is one of the best windows you'll see this week."
- Good: "A solid window — get on the water if you can."
- Fair: references `nextBestWindow` when available; otherwise generic.
- Poor: surfaces `nextBestWindow` as "Your next good overall window opens …".

The intent is *plain-English angler talk* — no jargon, explain the why, not just the what.

When `score < 40`, `avoidReason` is populated with the single worst-impact factor's explanation. Surface it in the UI when present.

---

## Modifying scores

Before changing a weight or threshold, ask:
- **Is the change empirically motivated?** Field data, published HSI, angler reports — not vibes.
- **Does it break the 100-point envelope?** Positive maxes should still sum to ~100 (currently 25 + 5 + 20 + 20 + 10 + 10 + 8 + 7 = 105 with the seasonal +3 bonus — generous on purpose so the score can saturate even when one factor misses).
- **Does it change the meaning of an existing factor?** Update this doc in the same commit. Don't drift.
- **Does it shift species ranks dramatically?** That's user-visible — call it out in the PR description.

Build and run on a real device to feel the change against live conditions before merging.
