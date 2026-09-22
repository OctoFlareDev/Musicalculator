import SwiftUI
import UIKit

private enum AppScreen: String, CaseIterable {
    case play = "Play"
    case files = "My Files"
    case calculator = "Calculator"

    var icon: String {
        switch self {
        case .play: "music.note"
        case .files: "folder"
        case .calculator: "plus.forwardslash.minus"
        }
    }
}

private struct CompositionSnapshot {
    let tokens: [MusicToken]
    let cursorIndex: Int
}

struct ContentView: View {
    @StateObject private var audio = AudioManager()
    @StateObject private var library = SongLibrary()
    @State private var screen: AppScreen = .play
    @State private var tokens: [MusicToken] = []
    @State private var cursorIndex = 0
    @State private var captureEnabled = false
    @State private var sharpHeld = false
    @State private var composerHeight: CGFloat = 310
    @State private var composerDragStart: CGFloat?
    @State private var showSavePrompt = false
    @State private var songName = ""
    @State private var currentSongID: SavedSong.ID?
    @State private var currentSongName: String?
    @State private var calculator = CalculatorState()
    @State private var composerToolsExpanded = false
    @State private var tempoEditing = false
    @State private var undoStack: [CompositionSnapshot] = []
    @State private var redoStack: [CompositionSnapshot] = []

    var body: some View {
        NavigationStack {
            screenContent
                .modifier(AdaptiveNavigationTitle(title: titleBarTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { titleBarActions }
        }
        .tint(.accentColor)
        .alert("Save song", isPresented: $showSavePrompt) {
            TextField("Song name", text: $songName)
            Button("Cancel", role: .cancel) { songName = "" }
            Button("Save") {
                saveAsNamedSong()
            }
            .disabled(songName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Give this sequence a name.")
        }
    }

    @ToolbarContentBuilder
    private var titleBarActions: some ToolbarContent {
        ToolbarItem(id: "navigation", placement: .topBarLeading) {
            Menu {
                Button {
                    startNewSong()
                } label: {
                    Label("New Song", systemImage: "doc.badge.plus")
                }

                Divider()

                ForEach(AppScreen.allCases, id: \.self) { item in
                    Button {
                        screen = item
                    } label: {
                        Label(
                            item.rawValue,
                            systemImage: screen == item ? "checkmark" : item.icon
                        )
                    }
                }
            } label: {
                Label("Open navigation panel", systemImage: "line.3.horizontal")
            }
            .accessibilityIdentifier("navigationMenu")
        }

        if screen == .play && hasPlayableTokens {
            ToolbarItem(id: "playback", placement: .topBarTrailing) {
                Button {
                    togglePlayback()
                } label: {
                    Label(audio.isPlayingSequence ? "Stop song" : "Play song",
                          systemImage: audio.isPlayingSequence ? "stop.fill" : "play.fill")
                }
                .accessibilityLabel(audio.isPlayingSequence ? "Stop song" : "Play song")
                .accessibilityIdentifier("playbackButton")
            }

            ToolbarItem(id: "save", placement: .topBarTrailing) {
                // Give the system native actions and label metadata when rehosting
                // horizontal/vertical bars, without a hosted UIButton or gesture state.
                Menu {
                    Button(action: promptSaveAs) {
                        Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                    }
                    .accessibilityIdentifier("saveAsAction")
                } label: {
                    Label("Save song", systemImage: "square.and.arrow.down")
                } primaryAction: {
                    saveCurrentSong()
                }
                .accessibilityIdentifier("saveSongButton")
            }
        }
    }

    private var titleBarTitle: String {
        if screen == .play, let currentSongName, !currentSongName.isEmpty {
            return currentSongName
        }
        return screen == .play ? "Musicalculator" : screen.rawValue
    }

    private var hasPlayableTokens: Bool {
        tokens.contains(where: { $0.kind == .note || $0.kind == .symbol })
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .play:
            playScreen
        case .files:
            filesScreen
        case .calculator:
            calculatorScreen
        }
    }

    private var playScreen: some View {
        AdaptiveCompositionLayout(composerHeight: composerHeight) {
            composer
        } keypad: {
            MusicalKeypad(
                dotHeld: $sharpHeld,
                onKey: handlePlayKey,
                showCalculatorOperators: false
            )
        } resizeHandle: { maximumHeight in
            resizeHandle(maximumHeight: maximumHeight)
        }
        .background(LiquidBackdrop())
    }

    private var composer: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Composition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(captureEnabled ? "Writing notes" : "Free play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)

            MusicGrid(
                tokens: tokens,
                cursorIndex: $cursorIndex,
                acceptsInput: captureEnabled,
                isPlaying: audio.isPlayingSequence
            )

            Divider()
            composerControlRow
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var composerControlRow: some View {
        HStack(spacing: 18) {
            if tempoEditing {
                Button {
                    tempoEditing = false
                } label: {
                    Image(systemName: "chevron.backward")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Back to editing tools")

                Spacer()
                Button("−5") { adjustTempo(by: -5) }
                    .buttonStyle(.glass)
                Text("♩ \(tempoAtCursor)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("+5") { adjustTempo(by: 5) }
                    .buttonStyle(.glass)
            } else if composerToolsExpanded {
                Button {
                    composerToolsExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Hide editing tools")

                Spacer()
                Button {
                    tempoEditing = true
                } label: {
                    Image(systemName: "metronome")
                }
                .accessibilityLabel("Adjust tempo at cursor")

                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(undoStack.isEmpty)
                .accessibilityLabel("Undo")

                Button(action: redo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(redoStack.isEmpty)
                .accessibilityLabel("Redo")
            } else {
                Button {
                    composerToolsExpanded = true
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Show editing tools")

                Spacer()
                Text("Write notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle("Write notes", isOn: $captureEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("writeNotesToggle")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
    }

    private func resizeHandle(maximumHeight: CGFloat) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 54, height: 28)
            .glassEffect(.regular.interactive(), in: Capsule())
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if composerDragStart == nil { composerDragStart = composerHeight }
                        let proposedHeight = (composerDragStart ?? composerHeight) + value.translation.height
                        composerHeight = min(max(proposedHeight, 190), maximumHeight)
                    }
                    .onEnded { _ in composerDragStart = nil }
            )
            .animation(nil, value: composerHeight)
            .accessibilityLabel("Resize note field")
    }

    private var filesScreen: some View {
        Group {
            if library.songs.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.tint)
                    Text("No saved songs yet")
                        .font(.title3.weight(.medium))
                    Text("Compose a sequence, then tap save.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(library.songs) { song in
                        HStack(spacing: 14) {
                            Button {
                                audio.toggleSequence(song.tokens)
                            } label: {
                                Image(systemName: "play.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.glass)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.name).font(.headline)
                                Text("\(song.tokens.reduce(0) { $0 + ($1.kind == .rest ? $1.restCount : (($1.kind == .note || $1.kind == .symbol) ? 1 : 0)) }) quarter-note beats")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Open") {
                                open(song)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                    .onDelete(perform: deleteSongs)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidBackdrop())
    }

    private var calculatorScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)
            Text(calculator.display)
                .font(.system(size: 56, weight: .light, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .accessibilityIdentifier("calculatorDisplay")
            Divider()
            MusicalKeypad(
                dotHeld: $sharpHeld,
                onKey: handleCalculatorKey,
                showCalculatorOperators: true
            )
            .padding(10)
        }
        .background(LiquidBackdrop())
    }

    private func handlePlayKey(_ key: String) {
        playSoundForKey(key, sharp: sharpHeld)
        guard captureEnabled, !audio.isPlayingSequence else { return }
        if let value = Int(key), (1...9).contains(value) {
            insertToken(.note(value, sharp: sharpHeld))
        } else if key == "0" || key == "00" || key == "%" {
            appendRest()
        } else if ["+", "−", "×", "÷", "="].contains(key) {
            insertToken(.symbol(key, sharp: sharpHeld))
        } else if key == "⌫" {
            removeLastToken()
        }
    }

    private func handleCalculatorKey(_ key: String) {
        playSoundForKey(key, sharp: sharpHeld)
        calculator.press(key)
    }

    private func playSoundForKey(_ key: String, sharp: Bool) {
        let soundName: String?
        switch key {
        case "1"..."9": soundName = key
        case "+": soundName = "+"
        case "−": soundName = "-"
        case "×": soundName = "mul"
        case "÷": soundName = "div"
        case "=": soundName = "="
        default: soundName = nil
        }
        if let soundName { audio.playSound(named: soundName, semitoneUp: sharp) }
    }

    private func appendRest() {
        if cursorIndex > 0, tokens[cursorIndex - 1].kind == .rest {
            recordUndoPoint()
            tokens[cursorIndex - 1].restCount += 1
        } else {
            insertToken(.rest())
        }
    }

    private func removeLastToken() {
        guard cursorIndex > 0 else { return }
        let last = tokens[cursorIndex - 1]
        recordUndoPoint()
        if last.kind == .rest && last.restCount > 1 {
            tokens[cursorIndex - 1].restCount -= 1
        } else {
            tokens.remove(at: cursorIndex - 1)
            cursorIndex -= 1
        }
    }

    private var tempoAtCursor: Int {
        tokens[..<min(cursorIndex, tokens.count)].reversed().first(where: { $0.kind == .tempo })?.tempoBPM ?? 90
    }

    private func adjustTempo(by amount: Int) {
        let newTempo = min(max(tempoAtCursor + amount, 30), 1000)
        recordUndoPoint()
        if cursorIndex > 0, tokens[cursorIndex - 1].kind == .tempo {
            let markerIndex = cursorIndex - 1
            let previousTempo = tokens[..<markerIndex]
                .reversed()
                .first(where: { $0.kind == .tempo })?
                .tempoBPM ?? 90
            if newTempo == previousTempo {
                tokens.remove(at: markerIndex)
                cursorIndex -= 1
            } else {
                tokens[markerIndex].tempoBPM = newTempo
            }
        } else {
            tokens.insert(.tempo(newTempo), at: cursorIndex)
            cursorIndex += 1
        }
    }

    private func insertToken(_ token: MusicToken) {
        recordUndoPoint()
        tokens.insert(token, at: cursorIndex)
        cursorIndex += 1
    }

    private func togglePlayback() {
        let playbackStart = cursorIndex == tokens.count ? 0 : cursorIndex
        audio.toggleSequence(tokens, from: playbackStart) { newIndex in
            cursorIndex = newIndex
        }
    }

    private func saveCurrentSong() {
        guard hasPlayableTokens else { return }
        guard let currentSongID, let savedSong = library.update(id: currentSongID, tokens: tokens) else {
            promptSaveAs()
            return
        }
        currentSongName = savedSong.name
    }

    private func promptSaveAs() {
        songName = currentSongName ?? ""
        showSavePrompt = true
    }

    private func saveAsNamedSong() {
        guard let savedSong = library.save(name: songName, tokens: tokens) else { return }
        currentSongID = savedSong.id
        currentSongName = savedSong.name
        songName = ""
    }

    private func open(_ song: SavedSong) {
        audio.stopSequence()
        tokens = song.tokens
        cursorIndex = song.tokens.count
        currentSongID = song.id
        currentSongName = song.name
        captureEnabled = true
        undoStack = []
        redoStack = []
        screen = .play
    }

    private func startNewSong() {
        audio.stopSequence()
        tokens.removeAll()
        cursorIndex = 0
        currentSongID = nil
        currentSongName = nil
        undoStack.removeAll()
        redoStack.removeAll()
        captureEnabled = false
        composerToolsExpanded = false
        tempoEditing = false
        screen = .play
    }

    private func deleteSongs(at offsets: IndexSet) {
        let deletedCurrentSong = offsets.contains { index in
            guard library.songs.indices.contains(index) else { return false }
            return library.songs[index].id == currentSongID
        }
        library.delete(at: offsets)
        if deletedCurrentSong {
            currentSongID = nil
            currentSongName = nil
        }
    }

    private func recordUndoPoint() {
        undoStack.append(CompositionSnapshot(tokens: tokens, cursorIndex: cursorIndex))
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(CompositionSnapshot(tokens: tokens, cursorIndex: cursorIndex))
        tokens = snapshot.tokens
        cursorIndex = snapshot.cursorIndex
    }

    private func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(CompositionSnapshot(tokens: tokens, cursorIndex: cursorIndex))
        tokens = snapshot.tokens
        cursorIndex = snapshot.cursorIndex
    }
}

private struct MusicGrid: View {
    let tokens: [MusicToken]
    @Binding var cursorIndex: Int
    let acceptsInput: Bool
    let isPlaying: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 8)

    private struct Entry: Identifiable {
        let id: String
        let token: MusicToken?
        let rawIndex: Int?
        let tempoLabel: Int?
        let showsCursor: Bool
    }

    private var entries: [Entry] {
        var result: [Entry] = []
        var activeTempo = 90
        var pendingTempoLabel: Int? = 90
        var musicalCellCount = 0
        let cursorTargetIndex = tokens.indices.first {
            $0 >= cursorIndex && tokens[$0].kind != .tempo
        }

        for (rawIndex, token) in tokens.enumerated() {
            if token.kind == .tempo {
                activeTempo = token.tempoBPM ?? 90
                pendingTempoLabel = activeTempo
                continue
            }

            result.append(Entry(
                id: token.id.uuidString,
                token: token,
                rawIndex: rawIndex,
                tempoLabel: pendingTempoLabel ?? (musicalCellCount == 0 ? activeTempo : nil),
                showsCursor: rawIndex == cursorTargetIndex
            ))
            pendingTempoLabel = nil
            musicalCellCount += 1
        }

        result.append(Entry(
            id: "trailing-placeholder",
            token: nil,
            rawIndex: nil,
            tempoLabel: pendingTempoLabel ?? (musicalCellCount == 0 ? activeTempo : nil),
            showsCursor: cursorTargetIndex == nil
        ))
        return result
    }

    private var cursorScrollID: String {
        entries.first(where: { $0.showsCursor })?.id ?? "trailing-placeholder"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(entries) { entry in
                        if let token = entry.token, let rawIndex = entry.rawIndex {
                            MusicCell(
                                token: token,
                                tempoLabel: entry.tempoLabel
                            )
                            .overlay(alignment: .topLeading) {
                                if entry.showsCursor {
                                    CursorIndicator(isActive: acceptsInput || isPlaying)
                                        .frame(height: 52)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { cursorIndex = rawIndex }
                            .id(entry.id)
                        } else {
                            trailingCell(tempoLabel: entry.tempoLabel, showsCursor: entry.showsCursor)
                                .contentShape(Rectangle())
                                .onTapGesture { cursorIndex = tokens.count }
                                .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .onChange(of: tokens.count) { _, _ in
                withAnimation { proxy.scrollTo(cursorScrollID, anchor: .bottom) }
            }
            .onChange(of: cursorIndex) { _, _ in
                withAnimation { proxy.scrollTo(cursorScrollID, anchor: .center) }
            }
        }
        .background(.ultraThinMaterial)
    }

    private func trailingCell(tempoLabel: Int?, showsCursor: Bool) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 52)
                .overlay(alignment: .leading) {
                    if showsCursor {
                        CursorIndicator(isActive: acceptsInput || isPlaying)
                    }
                }
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
            TempoStrip(bpm: tempoLabel)
        }
    }
}

private struct MusicCell: View {
    let token: MusicToken
    let tempoLabel: Int?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(token.kind == .rest ? Color.secondary.opacity(0.12) : Color.clear)
                Rectangle().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                Text(token.displayText)
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(token.isSharp ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if token.kind == .rest && token.restCount > 1 {
                    Text("×\(token.restCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            }
            .frame(height: 52)
            TempoStrip(bpm: tempoLabel)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch token.kind {
        case .note: token.isSharp ? "sharp \(token.value)" : "note \(token.value)"
        case .rest: "rest times \(token.restCount)"
        case .tempo: "tempo \(token.tempoBPM ?? 90)"
        case .symbol: "symbol \(token.symbol ?? "")"
        }
    }
}

private struct CursorIndicator: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
            .frame(width: isActive ? 3 : 1)
            .padding(.vertical, 6)
    }
}

private struct TempoStrip: View {
    let bpm: Int?

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.secondary.opacity(0.12))
            if let bpm {
                Text("\(bpm)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }
        }
        .frame(height: 13)
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.12), lineWidth: 0.5))
    }
}

private struct MusicalKeypad: View {
    @Binding var dotHeld: Bool
    let onKey: (String) -> Void
    let showCalculatorOperators: Bool

    private struct KeyPlacement: Identifiable {
        let label: String
        let column: Int
        let row: Int
        var rowSpan = 1
        var id: String { label }
    }

    private var placements: [KeyPlacement] {
        [
            KeyPlacement(label: "7", column: 0, row: 0),
            KeyPlacement(label: "8", column: 1, row: 0),
            KeyPlacement(label: "9", column: 2, row: 0),
            KeyPlacement(label: "%", column: 3, row: 0),
            KeyPlacement(label: "⌫", column: 4, row: 0),
            KeyPlacement(label: "4", column: 0, row: 1),
            KeyPlacement(label: "5", column: 1, row: 1),
            KeyPlacement(label: "6", column: 2, row: 1),
            KeyPlacement(label: "×", column: 3, row: 1),
            KeyPlacement(label: "÷", column: 4, row: 1),
            KeyPlacement(label: "1", column: 0, row: 2),
            KeyPlacement(label: "2", column: 1, row: 2),
            KeyPlacement(label: "3", column: 2, row: 2),
            KeyPlacement(label: "+", column: 3, row: 2, rowSpan: 2),
            KeyPlacement(label: "−", column: 4, row: 2),
            KeyPlacement(label: "0", column: 0, row: 3),
            KeyPlacement(label: "00", column: 1, row: 3),
            KeyPlacement(label: ".", column: 2, row: 3),
            KeyPlacement(label: "=", column: 4, row: 3)
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / 5
            let rowHeight = geometry.size.height / 4
            ZStack(alignment: .topLeading) {
                ForEach(placements) { key in
                    Group {
                        if key.label == "." {
                            HoldKey(label: key.label, isHeld: $dotHeld)
                        } else {
                            KeyButton(label: key.label) { onKey(key.label) }
                        }
                    }
                    .frame(width: columnWidth, height: rowHeight * CGFloat(key.rowSpan))
                    .position(
                        x: (CGFloat(key.column) + 0.5) * columnWidth,
                        y: (CGFloat(key.row) + CGFloat(key.rowSpan) / 2) * rowHeight
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier(showCalculatorOperators ? "calculatorKeypad" : "musicKeypad")
    }
}

private struct KeyButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Text(label)
            .font(.system(size: 25, weight: label == "=" ? .semibold : .regular, design: .rounded))
            .foregroundStyle(label == "=" ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay {
                InstantTouchControl(
                    highlightColor: UIColor.label.withAlphaComponent(0.08),
                    onPressChanged: { _ in },
                    onTap: action
                )
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
    }
}

private struct HoldKey: View {
    let label: String
    @Binding var isHeld: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 27, weight: .regular, design: .rounded))
            Text("hold: ♯")
                .font(.system(size: 9, weight: .medium))
                .opacity(isHeld ? 1 : 0.45)
        }
        .foregroundStyle(isHeld ? Color.accentColor : Color.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay {
            InstantTouchControl(
                highlightColor: UIColor.systemBlue.withAlphaComponent(0.12),
                onPressChanged: { isHeld = $0 },
                onTap: {}
            )
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Hold for sharp notes")
    }
}

private struct InstantTouchControl: UIViewRepresentable {
    let highlightColor: UIColor
    let onPressChanged: (Bool) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TouchControl {
        let control = TouchControl()
        control.isMultipleTouchEnabled = true
        control.isExclusiveTouch = false
        control.isAccessibilityElement = false
        control.highlightColor = highlightColor
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: [.touchDown, .touchDragEnter])
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchUpInside), for: .touchUpInside)
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchEnded), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        return control
    }

    func updateUIView(_ uiView: TouchControl, context: Context) {
        context.coordinator.parent = self
        uiView.highlightColor = highlightColor
    }

    final class Coordinator: NSObject {
        var parent: InstantTouchControl

        init(_ parent: InstantTouchControl) {
            self.parent = parent
        }

        @objc func touchDown(_ sender: TouchControl) {
            sender.setPressed(true)
            parent.onPressChanged(true)
        }

        @objc func touchUpInside(_ sender: TouchControl) {
            parent.onPressChanged(false)
            parent.onTap()
            sender.setPressed(false, minimumVisibleDuration: 0.09)
        }

        @objc func touchEnded(_ sender: TouchControl) {
            parent.onPressChanged(false)
            sender.setPressed(false)
        }
    }

    final class TouchControl: UIControl {
        var highlightColor = UIColor.label.withAlphaComponent(0.08) {
            didSet { highlightView.backgroundColor = highlightColor }
        }

        private let highlightView: UIView = {
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.alpha = 0
            view.layer.cornerRadius = 14
            view.layer.cornerCurve = .continuous
            return view
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            insertSubview(highlightView, at: 0)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            highlightView.frame = bounds.insetBy(dx: 5, dy: 5)
        }

        func setPressed(_ pressed: Bool, minimumVisibleDuration: TimeInterval = 0) {
            if pressed {
                highlightView.layer.removeAllAnimations()
                highlightView.alpha = 1
            } else {
                let hide = { self.highlightView.alpha = 0 }
                if minimumVisibleDuration > 0 {
                    UIView.animate(withDuration: 0.08, delay: minimumVisibleDuration, options: [.beginFromCurrentState], animations: hide)
                } else {
                    UIView.animate(withDuration: 0.08, animations: hide)
                }
            }
        }
    }
}

private struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.10), .clear, Color.cyan.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
