# TreeLens — On-Device Carbon Tree Classifier

A Flutter app for identifying tree species from photos using your EfficientNetB0 INT8 TFLite model.

SDK => 3.35.2

---

## Project structure

```
lib/
├── core/
│   ├── constants/app_constants.dart   ← model path, class names, thresholds
│   └── theme/app_theme.dart           ← forest green + earth palette, light + dark
├── data/
│   ├── datasources/
│   │   ├── classifier_service.dart    ← TFLite inference (INT8 model)
│   │   └── database_service.dart      ← SQLite via sqflite
│   ├── models/
│   │   ├── species_model.dart         ← species data structure
│   │   └── scan_result_model.dart     ← result + history record
│   └── repositories/
│       ├── species_repository.dart    ← loads species_lookup.json asset
│       └── scan_repository.dart       ← orchestrates inference + DB
├── presentation/
│   ├── providers/app_provider.dart    ← state via ChangeNotifier + Provider
│   └── screens/
│       ├── home_screen.dart           ← camera / gallery pick + stats
│       ├── result_screen.dart         ← species detail, CO₂ data, note
│       └── history_screen.dart        ← searchable, filterable history
└── main.dart                          ← splash + model loading gate
assets/
├── models/model_int8.tflite           ← YOUR model (copy from export zip)
└── data/species_lookup.json           ← species metadata (bundled)
```

---

## Setup steps

### 1. Copy model files

From your `tree_model_export.zip`, copy the INT8 model:
```
model_int8.tflite  →  assets/models/model_int8.tflite
```

The `species_lookup.json` is already generated and placed in `assets/data/`.

### 2. Fonts (SpaceGrotesk)

Download SpaceGrotesk from Google Fonts and place these in `assets/fonts/`:
- `SpaceGrotesk-Regular.ttf`
- `SpaceGrotesk-Medium.ttf`
- `SpaceGrotesk-Bold.ttf`

Or replace the font family in `pubspec.yaml` + `app_theme.dart` with a Google Fonts package call — e.g.:
```dart
import 'package:google_fonts/google_fonts.dart';
// use GoogleFonts.spaceGroteskTextTheme() in your ThemeData
```

### 3. Install dependencies
```bash
flutter pub get
```

### 4. Run
```bash
flutter run --release
```

---

## Model details (from your export)

| Detail | Value |
|--------|-------|
| Architecture | EfficientNetB0 |
| Format | INT8 TFLite |
| Input size | 224 × 224 × 3 |
| Preprocessing | pixel / 255.0 (float normalisation) |
| Output | Softmax [1, 8] |
| Test accuracy | 64.6% |
| Species classes | BAM, MGR, MNG, MOR, NEM, PEP, RSW, TEK |

---

## Features

| Feature | Detail |
|---------|--------|
| Camera scan | Live camera → classify |
| Gallery scan | Pick from photo library |
| On-device AI | EfficientNetB0 INT8, no network |
| Species detail | CO₂ kg/yr, DBH, height, biome, description |
| Carbon insight | Contextual CO₂ explanation per species |
| Confidence indicator | High / Medium / Low with colour coding |
| Top-3 predictions | Shows model's probability ranking |
| Scan history | SQLite-backed, persists across sessions |
| Search history | Live search by common or scientific name |
| Filter by CO₂ class | HIGH / MEDIUM / LOW filter chips |
| Swipe to delete | Dismissible history cards |
| Field notes | Per-scan editable text note |
| Share | Formatted text share via share_plus |
| Dark mode | Full dark theme, togglable in-app |
| Splash loading | Model loaded once on startup |

---

## Offline storage layout

- Scanned images: `{app_documents}/scans/{uuid}.jpg`
- History DB: `{databases}/treelens.db`
- Both directories created automatically on first run

---

## Tips for improving accuracy

The model was trained on research-grade iNaturalist photos. For best results:
- Take photos of **leaves, bark, or the full canopy** — these are the views the model saw most
- Good lighting, minimal blur
- If confidence is low (< 50%), try a different angle or photo

---

## Adding more species

1. Retrain with new classes using the existing pipeline (update `carbon_pilot_dataset.xlsx`)
2. Export new `model_int8.tflite` → replace in `assets/models/`
3. Update `AppConstants.classNames` to match new training class order
4. Add new entries to `assets/data/species_lookup.json`
5. Update `AppConstants.numClasses`
