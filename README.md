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
│   datasources/
│   │   ├── classifier_service.dart    ← TFLite inference + entropy/top-2 guard
│   │   ├── image_validator.dart       ← pure-Dart CV preprocessing (NEW)
│   │   └── database_service.dart      ← SQLite via sqflite
│   ├── models/
│   │   ├── species_model.dart         ← species data structure
│   │   └── scan_result_model.dart     ← result + history record
│   └── repositories/
│       ├── species_repository.dart    ← loads species_lookup.json asset
│       └── scan_repository.dart       ← orchestrates validation + inference + DB
├── presentation/
│   ├── providers/app_provider.dart    ← state via ChangeNotifier + Provider
│   └── screens/
│       ├── home_screen.dart           ← camera / gallery pick + rejection sheet
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
| Preprocessing | uint8 0–255 (INT8 quantised) |
| Output | Softmax [1, 8] — dequantised to 0.0–1.0 |
| Test accuracy | 64.6% |
| Species classes | BAM, MGR, MNG, MOR, NEM, PEP, RSW, TEK |

---

## Inference pipeline

Every image now passes through a 5-stage pipeline before the model sees it:

```
User picks image
      ↓
[1] Brightness check   → reject if too dark / overexposed
      ↓
[2] Blur check         → reject if Laplacian variance < 60
      ↓
[3] Contrast stretch   → lift flat images (skipped if dynamic range ≥ 100 pts)
      ↓
[4] Center crop        → keep central 85%, removes distracting borders
      ↓
[5] Model inference    → EfficientNetB0 INT8
      ↓
[6] Entropy guard      → reject if model is genuinely confused
[7] Top-2 gap guard    → reject if model is torn between two species
      ↓
Result screen or rejection sheet
```

Rejected images are **not saved to history**.

---

## Image validation (`image_validator.dart`)

Pure Dart — no model, no native plugins. Uses the `image` package already in `pubspec.yaml`.

| Check | Threshold | Rejection message |
|-------|-----------|-------------------|
| Brightness (min) | mean luminance < 35 / 255 | "Image is too dark" |
| Brightness (max) | mean luminance > 220 / 255 | "Image is overexposed" |
| Blur | Laplacian variance < 60 | "Image is too blurry" |

After passing checks, two enhancements are applied:

**Contrast stretch** — if the image dynamic range (max − min pixel luminance) is below 100 pts, the histogram is linearly stretched so the darkest pixel maps to 0 and the brightest to 255. Images with already good contrast are passed through unchanged.

**Center crop** — the central 85% of the image is cropped before resizing to 224×224. This reduces the influence of background clutter and borders that weren't present in the iNaturalist training photos.

To tune thresholds, edit `_Thresholds` inside `image_validator.dart`:
```dart
static const double minBrightness = 35.0;
static const double maxBrightness = 220.0;
static const double minLaplacianVariance = 60.0;
static const double cropFraction = 0.85;
```

---

## Inference guard (`classifier_service.dart`)

Runs after inference to catch two failure modes the confidence threshold alone misses.

### Why the confidence threshold alone isn't enough

The model only knows 8 tree species. When given a non-tree image (street scene, person, building), it still outputs a species name — it has no other choice. The confidence score is often low, but "low confidence + wrong species" looks identical to "low confidence + correct species (bad photo)" from the score alone.

Two additional signals distinguish these cases:

### 1. Entropy check (soft non-tree guard)

Shannon entropy measures how spread the probability is across all 8 classes:
- **Low entropy** → probability concentrated on 1–2 classes → model has a clear opinion
- **High entropy** → probability spread evenly → model is genuinely lost (likely not a known species)

```
entropy = -Σ (p_i × log2(p_i))   for all 8 classes
max possible = log2(8) = 3.0
```

If `entropy > 2.2` AND `max_score < 0.50` → rejected as `notRecognised`.

This is the **soft non-tree guard**. A street scene, a face, or a random object will trigger this because the model distributes its confusion evenly. A real tree species in a bad photo usually still concentrates probability on 1–2 classes.

### 2. Top-2 gap check (ambiguous prediction guard)

The gap between the #1 and #2 prediction scores:
- **Large gap** → model clearly prefers one species
- **Small gap** → model is nearly equally split between two species → unreliable

If `top2_gap < 0.10` AND `max_score < 0.50` → rejected as `ambiguous`.

### Tunable constants (`app_constants.dart`)

```dart
static const double entropyRejectionThreshold = 2.2;  // 0–3.0, higher = more permissive
static const double top2GapThreshold = 0.10;           // higher = stricter ambiguity check
static const double mediumConfidence = 0.50;           // floor score for both guards
```

Increase `entropyRejectionThreshold` if valid tree photos are being rejected. Decrease it if non-tree images are getting through.

---

## Rejection UX (`home_screen.dart`)

Rejections surface as a **bottom sheet** (not a snackbar) with:
- Contextual icon matching the rejection type (blur / dark / bright / unknown)
- Specific rejection message
- Tips card with actionable photography guidance
- "Try again" button

The sheet icon is automatically selected based on the message content — no extra enum passing needed.

---

## Confidence display (`result_screen.dart`)

The result screen confidence badge has three states:

| Score | Label | Colour |
|-------|-------|--------|
| ≥ 75% | High confidence | Green |
| 50–74% | Medium confidence | Amber |
| < 50% | Low confidence | Red + warning banner |

Low confidence results still show species data but display a banner: *"Low confidence — try a clearer photo of leaves, bark, or the full tree."*

---

## Features

| Feature | Detail |
|---------|--------|
| Camera scan | Live camera → classify |
| Gallery scan | Pick from photo library |
| On-device AI | EfficientNetB0 INT8, no network |
| Image validation | Brightness + blur check before inference |
| CV preprocessing | Contrast stretch + center crop |
| Entropy guard | Rejects images that look like non-tree inputs |
| Top-2 gap guard | Rejects ambiguous between-species predictions |
| Rejection sheet | Contextual bottom sheet with photography tips |
| Species detail | CO₂ kg/yr, DBH, height, biome, description |
| Carbon insight | Contextual CO₂ explanation per species |
| Confidence indicator | High / Medium / Low with colour coding |
| Top-3 predictions | Shows model's probability ranking |
| Scan history | SQLite-backed, persists across sessions (rejected images not saved) |
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

## Tips for best results

The model was trained on research-grade iNaturalist photos — typically close-up, well-lit, single-subject shots. Real-world photos that differ significantly from this distribution will get lower confidence scores.

**Photos that work well:**
- Close-up of leaves (single leaf or cluster)
- Bark texture shot from ~1m distance
- Full canopy from directly below
- Natural daylight, no harsh shadows

**Photos that struggle:**
- Distant landscape shots with multiple trees
- Mixed-subject images (tree + buildings, tree + people)
- Night shots or heavy shade
- Looking up through branches at sky (backlit)

---

## Adding more species

1. Retrain with new classes using the existing pipeline (update `carbon_pilot_dataset.xlsx`)
2. Export new `model_int8.tflite` → replace in `assets/models/`
3. Update `AppConstants.classNames` to match new training class order
4. Add new entries to `assets/data/species_lookup.json`
5. Update `AppConstants.numClasses`

---