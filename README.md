# Musicalculator

Musicalculator is a SwiftUI iOS calculator that turns keypad input into playable musical sequences. It combines a free-play instrument, a grid-based song editor, saved files, and a standard calculator in one Liquid Glass interface.

## Features

- **Free play:** every supported keypad button plays its bundled sound immediately.
- **Write Notes mode:** records notes, rests, and operators into a grid. It is off by default.
- **Sequence playback:** starts at the cursor, or from the beginning when the cursor is at the end.
- **Moving playback cursor:** follows the sequence while it plays.
- **Inline tempo changes:** BPM values appear in the strip beneath a cell and take no grid space.
- **Sharp notes:** hold `.` while pressing a note or audible operator to shift it up one semitone.
- **Compressed rests:** consecutive blanks share one cell and display a small `×N` count.
- **Undo and redo:** available from the expandable editor controls.
- **Saved songs:** name, save, save as, reopen, play, and delete compositions.
- **Calculator:** standard arithmetic with the same musical button feedback.
- **Silent-mode audio:** uses an iOS playback audio session, so sounds play while the mute switch is enabled.
- **Low-latency playback:** MP3s are decoded at launch and played through a pre-warmed voice pool.

## Composition controls

Open **Musicalculator** and enable **Write notes** to record keypad input.

| Input | Grid behavior |
| --- | --- |
| `1`–`9` | Inserts a note |
| Hold `.` + note | Inserts a sharp note such as `.6` in one cell |
| `+`, `−`, `×`, `÷`, `=` | Inserts an operator event |
| Hold `.` + audible operator | Inserts a sharp operator such as `.+` or `.×` |
| `0`, `00`, `%` | Inserts a rest/blank |
| `⌫` | Removes the event before the cursor |

Tap a grid cell to place the cursor at that event. New input is inserted at the cursor.

The upward chevron beneath the grid reveals:

- Tempo
- Undo
- Redo

Choose **Tempo** to adjust the BPM at the cursor in increments of five. A tempo marker is rendered in the narrow strip beneath its cell. The first cell defaults to `90`. If a marker is adjusted back to the previous tempo, the redundant marker removes itself automatically.

## Navigation

The leading toolbar menu is a native floating menu with:

- **New Song** — resets the current composition and editor state
- **Play** — opens the composer/free-play screen
- **My Files** — shows saved compositions
- **Calculator** — opens the standard calculator

When a composition contains playable events, Play/Stop and Save controls appear in the trailing navigation bar. Opening or saving a named file shows that name in the title bar. Tapping **Save** writes back to the current file; long-pressing **Save** opens **Save As** and creates a new file.

## Audio

Audio files live in [`Musicalculator/Sounds`](Musicalculator/Sounds). Notes `1`–`9` and the supported operators each use their corresponding MP3 file.

Playback is built with `AVAudioEngine` and `AVAudioUnitTimePitch`:

- Twelve voices are connected and warmed at startup.
- Sound files are decoded into PCM buffers before the first key press.
- Sharp events use a pitch shift of exactly `+100` cents.
- Pitch shifting does not change sample duration.

## Persistence

Saved songs are encoded with `Codable` and stored in `UserDefaults`. Each file includes its sequence tokens and inline tempo events. Tempo is not stored as one global song setting. Saving an already-open file updates that same stored item instead of creating a duplicate.

## Requirements

- macOS with Xcode and the iOS 26.5 SDK
- iOS 26.5 or later
- Swift 5

## Build and run

1. Open `Musicalculator.xcodeproj` in Xcode.
2. Select the **Musicalculator** scheme.
3. Choose an iPhone simulator or connected device.
4. Press **Run**.

Command-line build:

```sh
xcodebuild \
  -project Musicalculator.xcodeproj \
  -scheme Musicalculator \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Tests

The test suite covers sequence tokens, sharp symbols, tempo timing, calculator behavior, and audio-graph startup.

```sh
xcodebuild \
  -project Musicalculator.xcodeproj \
  -scheme Musicalculator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## Project structure

```text
Musicalculator/
├── AudioManager.swift       # Low-latency playback, pitch shifting, sequencing
├── ContentView.swift        # Navigation, composer, keypad, files, calculator UI
├── MusicModels.swift        # Tokens, saved songs, timing, calculator state
├── MusicalculatorApp.swift  # App entry point
├── Sounds/                  # Bundled note and operator MP3 files
└── Assets.xcassets          # App assets
```
