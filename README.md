<p align="center">
  <img src="MapPro/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="140" alt="MapPro icon" />
</p>

<h1 align="center">MapPro</h1>

<p align="center">
  A Google Maps-style iPhone app built with <b>SwiftUI</b> on top of the <b>Apple Maps engine</b>.<br/>
  Search, explore, compare routes, and move around the map with native 60 fps motion.
</p>

<p align="center">
  <img alt="Build" src="https://github.com/Heng-zm/mappro/actions/workflows/build-ipa.yml/badge.svg" />
  <img alt="Release" src="https://img.shields.io/github/v/release/Heng-zm/mappro?include_prereleases" />
  <img alt="iOS" src="https://img.shields.io/badge/iOS-17.0%2B-blue" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-orange" />
</p>

---

## What it does

MapPro recreates the everyday Google Maps phone experience using MapKit as the rendering engine — no third-party map SDK and no API keys.

- **Full-screen Apple Maps engine** with native pan, pinch, rotate, and 3D pitch gestures
- **Live search suggestions** powered by `MKLocalSearchCompleter`
- **Nearby category search** for restaurants, coffee, fuel, hotels, groceries, pharmacies, parking, EV charging, bars, attractions, parks, and shopping
- **Place details card** with category, address, distance, call, website, share, and directions
- **Coordinate tools** — long-press anywhere to drop a pin with a reverse-geocoded address, tap to copy decimal coordinates, or search `37.7749, -122.4194` directly (map links are understood too)
- **Saved places and pins** — bookmark any place or coordinate pin and reopen it later from the saved panel; stored on-device
- **Look Around** — full-screen Apple street-level imagery for supported coordinates
- **Directions for driving, walking, and transit** with alternate driving routes, ETA, distance, arrival time, and turn-by-turn steps
- **Route polyline** rendered on the map with automatic camera framing
- **Traffic overlay**, standard / satellite / hybrid layers, 2D / 3D camera, and a live compass
- **"Search this area"** after panning, just like Google Maps
- **Current location** with a one-tap recenter button and a permission banner when location is unavailable
- **Handoff to Apple Maps** for live turn-by-turn navigation
- **Smooth 60 fps interaction** through MapKit's native Metal renderer, lightweight SwiftUI overlays, and spring-driven UI transitions
- **Light and dark mode** friendly materials throughout

## Architecture

```
MapPro/
├── MapProApp.swift             App entry point
├── Engine/
│   ├── MapEngine.swift         Observable map brain: search, routes, location, camera commands
│   ├── MapContainerView.swift  UIViewRepresentable wrapper around MKMapView
│   ├── PlaceAnnotation.swift   MKAnnotation model for search results
│   └── PlaceAnnotationView.swift Custom category-colored map pin
├── Models/                     Place, saved places, favorites store, route options, travel modes, map layers, categories
├── Views/
│   ├── RootView.swift          Map + floating Google-style UI
│   ├── SearchBarView.swift
│   ├── SuggestionsView.swift
│   ├── CategoryChipsView.swift
│   ├── ResultsPanel.swift
│   ├── PlaceCardView.swift
│   ├── SavedPlacesPanel.swift
│   ├── LookAroundSheet.swift
│   ├── DirectionsSheet.swift
│   ├── MapControlsView.swift
│   └── ToastView.swift
└── Utilities/                  Theme, formatters, coordinate parser, haptics
```

The map itself is a real `MKMapView` wrapped in SwiftUI. This keeps gesture handling, tile rendering, overlays, and camera animation on Apple's optimized native path while the search, cards, sheets, and controls stay declarative in SwiftUI.

## Requirements

- Xcode 16 or newer
- iOS 17.0+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for generating the Xcode project

## Build locally

```bash
brew install xcodegen
xcodegen generate
open MapPro.xcodeproj
```

Then select the `MapPro` scheme and run on an iPhone simulator or device. To install on a physical device, choose your development team in **Signing & Capabilities**.

> The Xcode project is generated from [`project.yml`](project.yml) and intentionally not committed. Run `xcodegen generate` after cloning or changing source files.

## Automated IPA build

Every push to `main` runs [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) on a macOS runner. It:

1. Installs XcodeGen and generates the project
2. Archives the app for `generic/platform=iOS` with code signing disabled
3. Packages a real **unsigned `.ipa`** in a `Payload/` folder
4. Uploads the IPA and SHA-256 checksum as build artifacts

Pushing a tag such as `v1.1.0` also publishes a GitHub Release with the IPA attached:

```bash
git tag v1.1.0
git push origin v1.1.0
```

### Installing the unsigned IPA

The release build is unsigned. Install it with a sideloading tool such as **AltStore**, **Sideloadly**, or **Xcode** after re-signing with your own Apple ID:

1. Download `MapPro-<version>-unsigned.ipa` from the [latest release](https://github.com/Heng-zm/mappro/releases/latest)
2. Connect your iPhone
3. Import the IPA into your sideloading tool and sign with your Apple ID
4. Trust the developer certificate in **Settings → General → VPN & Device Management**

## Privacy

MapPro does not collect analytics and has no server. Location is used only on-device to center the map, search nearby, and calculate routes. Search and directions are handled by Apple's MapKit services under Apple's privacy policy.

## Notes

- Map data, search results, transit availability, and business details come from Apple Maps and vary by region.
- Apple Maps does not expose a full turn-by-turn session API for third-party apps, so **Start navigation** hands off to the system Maps app for live guidance.
- This is an independent educational clone. Google Maps is a trademark of Google LLC; MapPro is not affiliated with Google or Apple.
