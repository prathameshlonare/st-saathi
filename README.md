<p align="center">
  <img src="docs/icon.png" alt="ST Saathi icon" width="96" />
</p>

<h1 align="center">ST Saathi</h1>

<p align="center">Maharashtra ST bus timetable, offline and in your pocket.</p>

<p align="center">
  <a href="https://flutter.dev/"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44-blue?style=flat-square" /></a>
  <a href="https://dart.dev/"><img alt="Dart" src="https://img.shields.io/badge/Dart-3.12-blue?style=flat-square" /></a>
  <a href="https://www.sqlite.org/"><img alt="SQLite" src="https://img.shields.io/badge/SQLite-Offline-green?style=flat-square" /></a>
  <a href="https://m3.material.io/"><img alt="Material 3" src="https://img.shields.io/badge/Material%203-Design-red?style=flat-square" /></a>
  <a href="https://developer.android.com/"><img alt="Android" src="https://img.shields.io/badge/Android-8.0+-brightgreen?style=flat-square" /></a>
</p>

## The problem it solves

You're at an MSRTC depot. The departure board is faded, broken, or nobody's around to ask. You know your village. You know where you want to go. But which bus leaves when? And does it stop where you need it to?

ST Saathi answers those questions offline. Install it once and the whole timetable lives on your phone: no data, no Wi-Fi, no signal.

## What the app does

| Feature | What it does |
|---------|--------------|
| Search buses | Pick origin and destination, see every bus on that route |
| Departure times | Sorted by time, with a countdown to departure |
| Bus type & via-stops | Ordinary, Shivneri, Shivshahi, Hirkani, Sleeper, plus intermediate stops |
| Connecting routes | When no direct bus runs, shows 1-stop junction options |
| Saved routes | Bookmark the routes you take every day |
| Marathi mode | Full UI in Marathi, including Devanagari numerals |
| Dark mode | Follows the system theme |
| 100% offline | Stores the whole timetable on the phone |

## Data sources

The timetable comes from two open sources, merged and cleaned:

- **cookingconvertertools-web/msrtc-bus-timetable**: 45 depots across Vidarbha, Khandesh, and Marathwada (Amravati, Akola, Wardha, Chandrapur, Beed, Bhusawal, Yavatmal, Nagpur, and more)
- **vaibhavmanch3kar/maharashtra-st-timetable**: Western Maharashtra and Konkan routes (Pune Swargate, Mumbai Central, Ratnagiri, Kolhapur, Kurundwad)

We kept only the fields the sources publish: origins, destinations, departure times, via-stops, and bus types. If a source didn't publish arrival times, fares, or seat counts, they aren't in the app.

Full provenance and known gaps are in `data_source/cookingconverter/README.md` and `data_source/vaibhav/README.md`.

## Quick start

1. Download the APK from the [Releases page](https://github.com/prathameshlonare/st-saathi/releases).
2. Install it on Android 8.0 or newer.
3. Pick your origin and destination, then search.

## Built with

- **Flutter** for the UI
- **SQLite** for the offline database
- **Material Design 3** for components and theming
- **Mukta** for Devanagari text

## Landing page

The download page sits in `docs/`: plain HTML, CSS, and JavaScript, no build step. It ships in English and Marathi, paints the fleet types in real MSRTC livery colors, and reads `release-metadata.json` for the current version and download link. GitHub Actions redeploys it to GitHub Pages on every release.

<details>
<summary>Repository structure</summary>

```
st_saathi/
├── lib/                  # Flutter application code
├── assets/
│   ├── database/         # Offline SQLite timetable (1.24 MB)
│   └── fonts/            # Mukta font family for Marathi
├── data_source/          # Raw source data and provenance notes
│   ├── cookingconverter/ # 45 depot timetable files
│   └── vaibhav/          # 278 bilingual station pairs
├── scripts/              # compile_database.js builds the SQLite asset
├── test/                 # Unit and widget tests (28 passing)
├── android/              # Android native code and signing config
├── docs/                 # Landing page and release-metadata.json
├── .github/workflows/    # release.yml builds, signs, and publishes
└── pubspec.yaml          # Project configuration
```
</details>

<details>
<summary>Release and update process</summary>

Push a version tag and GitHub Actions builds the APK, signs it, and publishes the release. The app checks for updates on launch and offers a popup when a new APK exists. "Update Now" opens the download page.

</details>
