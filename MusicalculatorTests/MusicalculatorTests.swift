//
//  MusicalculatorTests.swift
//  MusicalculatorTests
//
//  Created by Flare ​ on 7/8/26.
//

import Testing
import CoreGraphics
@testable import Musicalculator

struct MusicalculatorTests {
    @Test func portraitCompositionSizeSurvivesACompactLayout() {
        let portrait = CompositionLayoutMetrics(size: CGSize(width: 650, height: 900), hasActiveDivision: false)
        let outerDisplay = CompositionLayoutMetrics(size: CGSize(width: 390, height: 480), hasActiveDivision: false)
        let preferredHeight: CGFloat = 310

        #expect(portrait.composerHeight(preferred: preferredHeight) == preferredHeight)
        #expect(outerDisplay.composerHeight(preferred: preferredHeight) < preferredHeight)
        #expect(portrait.composerHeight(preferred: preferredHeight) == preferredHeight)
        #expect(!portrait.isLocked)
    }

    @Test func foldAndWideLayoutsDisableManualResizing() {
        let wide = CGSize(width: 900, height: 650)
        let tall = CGSize(width: 650, height: 900)
        #expect(CompositionLayoutMetrics(size: wide, hasActiveDivision: false).isLocked)
        #expect(CompositionLayoutMetrics(size: wide, hasActiveDivision: true).isLocked)
        #expect(CompositionLayoutMetrics(size: tall, hasActiveDivision: true).isLocked)
        #expect(!CompositionLayoutMetrics(size: tall, hasActiveDivision: false).isLocked)
    }

    @Test(arguments: [400.0, 480.0, 600.0, 900.0])
    func compactLayoutLeavesRoomForFourKeyRows(height: Double) {
        let metrics = CompositionLayoutMetrics(size: CGSize(width: 390, height: height), hasActiveDivision: false)
        let keypadHeight = height - metrics.composerHeight(preferred: 700) - 56
        #expect(keypadHeight >= 4 * 44)
    }

    @Test func sharpNoteUsesOneToken() {
        let token = MusicToken.note(5, sharp: true)
        #expect(token.displayText == ".5")
        #expect(token.kind == .note)
    }

    @Test func calculatorPerformsBasicOperation() {
        var calculator = CalculatorState()
        calculator.press("8")
        calculator.press("×")
        calculator.press("7")
        calculator.press("=")
        #expect(calculator.display == "56")
    }

    @Test func backspaceClearsCalculatedResult() {
        var calculator = CalculatorState()
        calculator.press("8")
        calculator.press("+")
        calculator.press("2")
        calculator.press("=")
        calculator.press("⌫")
        #expect(calculator.display == "0")
    }

    @Test func ninetyBPMUsesQuarterNoteBeats() {
        #expect(MusicTiming.quarterNoteNanoseconds(bpm: 90) == 666_666_666)
    }

    @Test func tempoIsAnInlineToken() {
        let token = MusicToken.tempo(120)
        #expect(token.kind == .tempo)
        #expect(token.displayText == "♩120")
    }

    @Test func operatorIsAQuarterNoteSequenceToken() {
        let token = MusicToken.symbol("×")
        #expect(token.displayText == "×")
        #expect(token.soundName == "mul")
    }

    @Test func sharpOperatorUsesOneCell() {
        let token = MusicToken.symbol("+", sharp: true)
        #expect(token.displayText == ".+")
        #expect(token.isSharp)
        #expect(token.soundName == "+")
    }

    @Test @MainActor func audioGraphStartsAfterVoiceConnection() async {
        let audio = AudioManager()
        audio.playSound(named: "5")
        audio.playSound(named: "5", semitoneUp: true)
        try? await Task.sleep(nanoseconds: 800_000_000)
    }
}
