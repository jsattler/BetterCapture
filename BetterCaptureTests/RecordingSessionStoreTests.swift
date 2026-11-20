//
//  RecordingSessionStoreTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 20.11.26.
//

import Testing
@testable import BetterCapture

struct RecordingSessionStoreTests {

    private struct Recording: Equatable {
        var id: String
        var name: String?
        var isActive: Bool
    }

    private func select(_ selector: String?, in recordings: [Recording]) throws(ControlError) -> Recording {
        try RecordingSessionStore.select(selector, in: recordings, id: \.id, name: \.name, isActive: \.isActive)
    }

    private func error(_ body: () throws(ControlError) -> Recording) -> ControlError? {
        do {
            _ = try body()
            return nil
        } catch {
            return error
        }
    }

    @Test func withoutSelectorPicksTheOnlyActiveRecording() throws {
        let active = Recording(id: "b", name: nil, isActive: true)
        #expect(try select(nil, in: [Recording(id: "a", name: nil, isActive: false), active]) == active)
    }

    @Test func withoutSelectorFailsWhenNothingIsActive() {
        let error = error { () throws(ControlError) in try select(nil, in: [Recording(id: "a", name: nil, isActive: false)]) }
        #expect(error?.code == .notRecording)
    }

    @Test func withoutSelectorIsAmbiguousWhenSeveralAreActive() {
        let recordings = [
            Recording(id: "a", name: "one", isActive: true),
            Recording(id: "b", name: nil, isActive: true)
        ]
        let error = error { () throws(ControlError) in try select(nil, in: recordings) }
        #expect(error?.code == .ambiguous)
        #expect(error?.candidates == ["a\tone", "b\t"])
    }

    @Test func matchesIDOrName() throws {
        let recordings = [
            Recording(id: "a", name: "demo", isActive: true),
            Recording(id: "b", name: "intro", isActive: true)
        ]
        #expect(try select("b", in: recordings) == recordings[1])
        #expect(try select("Demo", in: recordings) == recordings[0])
    }

    @Test func activeRecordingWinsOverEndedOneWithTheSameName() throws {
        let recordings = [
            Recording(id: "a", name: "demo", isActive: false),
            Recording(id: "b", name: "demo", isActive: true)
        ]
        #expect(try select("demo", in: recordings) == recordings[1])
    }

    @Test func matchesEndedRecordings() throws {
        let ended = Recording(id: "a", name: "demo", isActive: false)
        #expect(try select("a", in: [ended]) == ended)
        #expect(try select("demo", in: [ended]) == ended)
    }

    @Test func unknownSelectorIsNotFound() {
        let error = error { () throws(ControlError) in try select("zzz", in: [Recording(id: "a", name: nil, isActive: true)]) }
        #expect(error?.code == .notFound)
    }
}
