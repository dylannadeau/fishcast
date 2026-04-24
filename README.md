# FishCast

Hyperlocal fishing forecasts powered by WeatherKit — giving anglers real-time conditions and bite-window predictions for their favorite spots.

---

## Screenshots

| Home | Forecast | Spot Detail |
|------|----------|-------------|
| _coming soon_ | _coming soon_ | _coming soon_ |

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15.0+ |
| iOS Deployment Target | 17.0+ |
| Apple Developer Account | Required (WeatherKit entitlement) |

---

## Setup

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/fishcast.git
cd fishcast

# 2. Open the project
open FishCast.xcodeproj

# 3. Add the WeatherKit capability
#    Xcode → Target → Signing & Capabilities → + Capability → WeatherKit

# 4. Select your development team and run on a physical device
```

> **Note:** WeatherKit requires a paid Apple Developer Program membership and does not work in the Simulator without a valid entitlement.

---

## Features

- **Bite Windows** — ML-driven predictions for peak feeding activity based on tide, pressure, and light levels
- **Hyperlocal Weather** — WeatherKit data scoped to specific fishing spots, not just the nearest city
- **Saved Spots** — Pin your favorite locations and get push notifications before prime conditions
- **Species Filters** — Condition thresholds tailored per target species (bass, trout, saltwater, etc.)
- **Offline Mode** — Last-known forecast cached locally for areas with poor connectivity

---

## Folder Structure

```
FishCast/
├── Models/          # Data types, Codable structs, enums
├── Views/           # SwiftUI views and reusable components
├── ViewModels/      # ObservableObject classes, business logic
├── Services/        # WeatherKit, location, networking, persistence
└── Utilities/       # Extensions, helpers, DesignSystem constants
```

---

## Contributing

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code — App Store builds only |
| `develop` | Integration branch; all features merge here first |
| `feature/xxx` | Individual feature work branched off `develop` |

### Commit Message Format

```
[Feature] Add bite-window card to home screen
[Fix] Correct tidal offset calculation for EST timezone
[Refactor] Extract WeatherKit calls into dedicated service
[Docs] Update setup instructions for Xcode 16
```

Pull requests from `feature/xxx` → `develop`. Only release PRs go `develop` → `main`.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
