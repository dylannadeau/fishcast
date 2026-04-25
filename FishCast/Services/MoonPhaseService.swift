import CoreLocation
import Foundation

/// Self-contained moon-phase + moonrise/set calculator.
///
/// Phase math follows Jean Meeus *Astronomical Algorithms*, simplified to a
/// single anchor (the new moon of 2000-01-06 18:14 UTC) plus the synodic
/// month length. Moonrise/set use a low-precision lunar position formula and
/// the standard horizon hour-angle equation. Accuracy is roughly ±15 minutes
/// for rise/set, which is plenty for an angler-facing UI.
struct MoonPhaseService {

    static let shared = MoonPhaseService()

    private static let synodicMonth = 29.530_588_853
    private static let knownNewMoonJD = 2451550.1            // 2000-01-06 14:24 UTC
    private static let j2000 = 2451545.0
    private static let radians = Double.pi / 180

    // MARK: - Public API

    func info(for date: Date, at coordinate: CLLocationCoordinate2D? = nil) -> MoonInfo {
        let jd = julianDate(for: date)
        let age = moonAge(julianDate: jd)
        let phase = phase(forAge: age)
        let illumination = illumination(forAge: age)

        var rise: Date? = nil
        var set: Date? = nil
        if let coordinate {
            (rise, set) = riseAndSet(for: date, at: coordinate)
        }

        return MoonInfo(
            date: date,
            phase: phase,
            ageDays: age,
            illumination: illumination,
            moonrise: rise,
            moonset: set
        )
    }

    // MARK: - Phase / age / illumination

    private func julianDate(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2440587.5
    }

    private func moonAge(julianDate jd: Double) -> Double {
        let synodic = MoonPhaseService.synodicMonth
        var age = (jd - MoonPhaseService.knownNewMoonJD)
            .truncatingRemainder(dividingBy: synodic)
        if age < 0 { age += synodic }
        return age
    }

    private func phase(forAge age: Double) -> MoonPhase {
        // 8 phases on a 29.53-day cycle. New moon spans the wrap (≤1.84 or ≥27.68);
        // remaining phases get 3.69-day windows.
        switch age {
        case ..<1.84:           return .newMoon
        case 1.84 ..< 5.53:     return .waxingCrescent
        case 5.53 ..< 9.22:     return .firstQuarter
        case 9.22 ..< 12.91:    return .waxingGibbous
        case 12.91 ..< 16.61:   return .fullMoon
        case 16.61 ..< 20.30:   return .waningGibbous
        case 20.30 ..< 23.99:   return .lastQuarter
        case 23.99 ..< 27.68:   return .waningCrescent
        default:                return .newMoon
        }
    }

    private func illumination(forAge age: Double) -> Double {
        // (1 - cos(phase angle)) / 2 — sine-cosine approximation accurate to ~1%.
        let phaseAngle = 2 * .pi * age / MoonPhaseService.synodicMonth
        return (1 - cos(phaseAngle)) / 2
    }

    // MARK: - Moon position (low precision)

    /// Returns the moon's apparent right ascension and declination (radians)
    /// at the given Julian Date. Based on Meeus §47, dropping minor terms.
    private func moonEquatorial(julianDate jd: Double) -> (ra: Double, dec: Double) {
        let d = jd - MoonPhaseService.j2000
        let r = MoonPhaseService.radians

        // Mean longitude, anomaly, argument of latitude (degrees)
        let L = (218.316 + 13.176396 * d).truncatingRemainder(dividingBy: 360)
        let M = (134.963 + 13.064993 * d).truncatingRemainder(dividingBy: 360)
        let F = ( 93.272 + 13.229350 * d).truncatingRemainder(dividingBy: 360)

        // Geocentric ecliptic coordinates
        let lambda = (L + 6.289 * sin(M * r)) * r           // longitude (rad)
        let beta   = (5.128 * sin(F * r)) * r               // latitude  (rad)

        // Mean obliquity of the ecliptic (Meeus 21.2)
        let epsilon = (23.439 - 0.0000004 * d) * r

        let sinDec = sin(beta) * cos(epsilon)
                   + cos(beta) * sin(epsilon) * sin(lambda)
        let dec = asin(sinDec)

        let y = sin(lambda) * cos(epsilon) - tan(beta) * sin(epsilon)
        let x = cos(lambda)
        let ra = atan2(y, x)

        return (ra, dec)
    }

    // MARK: - Rise / set

    /// Approximate moonrise/moonset for the calendar day containing `date`.
    /// Single-pass — accurate enough for UI display, not for celestial nav.
    private func riseAndSet(for date: Date, at coord: CLLocationCoordinate2D) -> (Date?, Date?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let dayStartUTC = calendar.startOfDay(for: date)
        let noonUTC = dayStartUTC.addingTimeInterval(12 * 3600)
        let jdNoon = julianDate(for: noonUTC)

        let (ra, dec) = moonEquatorial(julianDate: jdNoon)

        let r = MoonPhaseService.radians
        let phi = coord.latitude * r
        // Standard altitude for moon rise/set (refraction + parallax + semidiameter).
        let h0 = -0.583 * r

        let cosH = (sin(h0) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
        if cosH > 1 || cosH < -1 {
            return (nil, nil)   // moon never rises or never sets at this latitude/day
        }
        let H = acos(cosH)                          // hour angle (radians)
        let raDeg = ra * 180 / .pi
        let HDeg = H * 180 / .pi

        // GMST at 0h UT (Meeus 12.4, simplified)
        let jd0 = julianDate(for: dayStartUTC)
        let T = (jd0 - MoonPhaseService.j2000) / 36525
        let gmst0 = (100.460_618_37 + 36000.770_053_608 * T)
            .truncatingRemainder(dividingBy: 360)

        // UT (hours) when moon is at hour angle ±H:
        //   LST = RA ± H        →  GMST = LST - longitude
        //   UT_h = (GMST - GMST0) / 1.00273790935 / 15
        let solveUT: (Double) -> Double = { hourAngleDeg in
            var deg = raDeg + hourAngleDeg - coord.longitude - gmst0
            deg = deg.truncatingRemainder(dividingBy: 360)
            if deg < 0 { deg += 360 }
            return deg / 15.0 / 1.002_737_909_35
        }

        let riseHours = solveUT(-HDeg)
        let setHours  = solveUT( HDeg)

        let rise = dayStartUTC.addingTimeInterval(riseHours * 3600)
        let set  = dayStartUTC.addingTimeInterval(setHours  * 3600)

        return (rise, set)
    }
}
