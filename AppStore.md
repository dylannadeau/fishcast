# FishCast — App Store Submission Reference

Drop these strings into App Store Connect when submitting. All copy is
final-form except where noted with `<replace>`.

## App name
FishCast

## Subtitle (30 char max)
Know Before You Go

## Promotional text (170 char max)
Real-time fishing conditions powered by weather, barometric pressure, moon, and tides — plus a built-in catch log. Plan your trip before you hit the water.

## Description (4000 char max)
FishCast turns the weather forecast into something you can actually use on the water.

Every fishing trip is a bet against the conditions — pressure, wind, cloud cover, time of day, water temperature, lunar pull. FishCast pulls all of it from Apple WeatherKit, NOAA Tides & Currents, and a built-in moon-phase model, then fuses it into a single 0–100 fishing score so you can decide at a glance whether today is the day.

KEY FEATURES

• Today's Fishing Score — A 0–100 score with rating (Excellent / Good / Fair / Poor) and a plain-English summary of why. Per-factor breakdown shows exactly which conditions are helping or hurting.

• 7-Day Forecast — Daily score, high/low temperature, conditions glyph, and the moon phase for every day in the next week.

• Tide Charts — Live hi/lo predictions for the nearest NOAA station rendered as a smooth sine curve. Inland? FishCast quietly hides the tide section.

• Moon Phase + Rise/Set — Computed locally with a Jean Meeus astronomy model, so it's accurate offline.

• Best Bets Today — Top three species likely biting right now (Bass, Trout, Walleye, Pike, Catfish, Crappie, Perch) with technique tips drawn from published fisheries biology.

• Map of Your Spots — Long-press to drop a pin, save notes, and see a live fishing score for each spot on demand.

• Catch Log — Track every fish you land with photo, weight, length, lure, and an automatic weather snapshot. Filter by species or spot, sort by date or weight, export the whole log to CSV.

• Daily Reminder — Optional once-a-day notification at the time you choose.

• Home Screen Widgets — Small and medium widgets show today's score and the peak time window without opening the app.

• Imperial or Metric — Toggle anytime in Settings.

PRIVACY

FishCast does not track you. Your location is used only to fetch weather and tide data for nearby stations, and never leaves your device. Your spots, catches, and photos are stored locally — there is no account and no cloud sync.

Built for serious anglers and weekend warriors. iOS 17 required.

## Keywords (100 char max — comma-separated)
fishing,weather,tides,bass,trout,catch log,barometer,moon,fishing forecast,angler

## Support URL
https://example.com/fishcast/support  <replace>

## Marketing URL
https://example.com/fishcast  <replace>

## Privacy Policy URL
https://example.com/fishcast/privacy  <replace>

## Category
Primary: Sports
Secondary: Weather

## Age rating
4+

## Copyright
© 2026 FishCast.

## What's New (per release)
v1.0 — Launch.
- 0–100 fishing score with full factor breakdown
- 7-day forecast, moon, and NOAA tide charts
- Map of saved spots with per-spot scoring
- Catch log with photo, weather snapshot, CSV export
- Small + medium home screen widgets
- Daily reminder notifications

## Reviewer notes
- WeatherKit access: relies on Apple's WeatherKit entitlement (no separate API key required, granted via team membership).
- Tide data: NOAA Tides & Currents public REST API (no key, no auth).
- Notifications and location are both optional — app works without them.
- App Group `group.com.fishcast.shared` is shared between the FishCast app and FishCastWidget extension to render the home-screen widget.

## Screenshot checklist (per device class)
1. Dashboard — fishing score ring + conditions row
2. Forecast — 7-day list + moon section
3. Forecast — tide chart with hi/lo markers
4. Map — pin + score sheet
5. Log — catch list with photos + stats card
6. Widget — medium widget on home screen
