//
//  TargetResolverTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 20.11.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import BetterCapture

struct TargetResolverTests {

    private let windows = [
        TargetResolver.Candidate(item: 1, id: "101", name: "Inbox"),
        TargetResolver.Candidate(item: 2, id: "102", name: "Inbox – Archive"),
        TargetResolver.Candidate(item: 3, id: "103", name: "Notes"),
        TargetResolver.Candidate(item: 4, id: "104", name: "Release Notes")
    ]

    @Test func matchesID() throws {
        #expect(try TargetResolver.resolve("103", in: windows, kind: "window") == 3)
    }

    @Test func exactNameWinsOverPartialMatches() throws {
        #expect(try TargetResolver.resolve("inbox", in: windows, kind: "window") == 1)
        #expect(try TargetResolver.resolve("NOTES", in: windows, kind: "window") == 3)
    }

    @Test func matchesUniquePartialName() throws {
        #expect(try TargetResolver.resolve("archive", in: windows, kind: "window") == 2)
    }

    @Test func ambiguousPartialNameListsCandidates() {
        let windows = [
            TargetResolver.Candidate(item: 1, id: "101", name: "Project Plan"),
            TargetResolver.Candidate(item: 2, id: "102", name: "Project Notes")
        ]

        #expect {
            try TargetResolver.resolve("project", in: windows, kind: "window")
        } throws: { error in
            let error = error as? ControlError
            return error?.code == .ambiguous && error?.candidates?.count == 2
        }
    }

    @Test func unknownTargetIsNotFound() {
        #expect {
            try TargetResolver.resolve("Calendar", in: windows, kind: "window")
        } throws: { error in
            (error as? ControlError)?.code == .notFound
        }
    }

    @Test func areaIsRoundedToEvenPixels() throws {
        let area = AreaRect(left: 10, top: 20, width: 100.5, height: 51)

        let rect = try TargetResolver.sourceRect(for: area, displaySize: CGSize(width: 1512, height: 982), scale: 1)

        #expect(rect == CGRect(x: 10, y: 20, width: 102, height: 52))
    }

    @Test func areaOutsideDisplayIsRejected() {
        let area = AreaRect(left: 1500, top: 0, width: 100, height: 100)

        #expect {
            try TargetResolver.sourceRect(for: area, displaySize: CGSize(width: 1512, height: 982), scale: 2)
        } throws: { error in
            (error as? ControlError)?.code == .invalidRequest
        }
    }
}
