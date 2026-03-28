//
//  ContainerFormatTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
@testable import BetterCapture

struct ContainerFormatTests {

    // MARK: - supportedVideoCodecs

    @Test func movSupportsAllCodecs() {
        let codecs = ContainerFormat.mov.supportedVideoCodecs
        #expect(codecs == VideoCodec.allCases)
    }

    @Test func mp4SupportsOnlyH264AndHEVC() {
        let codecs = ContainerFormat.mp4.supportedVideoCodecs
        #expect(codecs == [.h264, .hevc])
        #expect(!codecs.contains(.proRes422))
        #expect(!codecs.contains(.proRes4444))
    }

    // MARK: - supportsAlphaChannel

    @Test func supportsAlphaChannel() {
        #expect(ContainerFormat.mov.supportsAlphaChannel == true)
        #expect(ContainerFormat.mp4.supportsAlphaChannel == false)
    }

    // MARK: - supportedAudioCodecs

    @Test func movSupportsAllAudioCodecs() {
        let codecs = ContainerFormat.mov.supportedAudioCodecs
        #expect(codecs == AudioCodec.allCases)
    }

    @Test func mp4SupportsOnlyAAC() {
        let codecs = ContainerFormat.mp4.supportedAudioCodecs
        #expect(codecs == [.aac])
        #expect(!codecs.contains(.pcm))
    }

    // MARK: - fileExtension

    @Test func fileExtension() {
        #expect(ContainerFormat.mov.fileExtension == "mov")
        #expect(ContainerFormat.mp4.fileExtension == "mp4")
    }

    // MARK: - Identifiable & RawValue

    @Test func rawValues() {
        #expect(ContainerFormat.mov.rawValue == "mov")
        #expect(ContainerFormat.mp4.rawValue == "mp4")
    }

    @Test func identifiable() {
        for format in ContainerFormat.allCases {
            #expect(format.id == format.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(ContainerFormat.allCases.count == 2)
    }
}
