//
//  MusicalculatorTests.swift
//  MusicalculatorTests
//
//  Created by Flare ​ on 7/8/26.
//

import Testing
@testable import Musicalculator

struct MusicalculatorTests {
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
