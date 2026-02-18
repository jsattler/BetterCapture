# BetterCapture Documentation

## Concepts

Background knowledge for understanding screen recording settings and terminology.

- [Video Concepts:](concepts/VIDEO.md) Resolution, frame rate, codecs, compression, containers, pixel formats, color spaces, HDR, alpha channel.
- [Audio Concepts:](concepts/AUDIO.md) Sample rate, bit depth, channels, audio codecs (AAC, PCM), synchronization.
- [Glossary:](concepts/GLOSSARY.md) Quick-reference table of terms.

## ScreenCaptureKit

How Apple's ScreenCaptureKit and AVFoundation frameworks work together for screen recording.

- [Overview:](screen-capture-kit/OVERVIEW.md) Key classes (`SCStream`, `SCStreamConfiguration`, `AVAssetWriter`, etc.), class relationships, and the capture-to-disk pipeline.
- [Configuration Reference:](screen-capture-kit/CONFIGURATION.md) How `SCStreamConfiguration` properties map to video/audio concepts. How SCK and AVFoundation settings must align.

## Architecture

How BetterCapture is built. Component structure, data flow, and implementation details.

- [Architecture Overview:](architecture/OVERVIEW.md) MVVM structure, component diagram, recording data flow, codec/container support.
- [Output Settings:](architecture/OUTPUT.md) Resolution, bitrate, codec/container compatibility, pixel formats, color profiles, HDR, automatic settings adjustment.

## Specifications

- [App Specification:](SPEC.md) UI design, functional requirements, configuration defaults.
- [Feature Specs:](specs/) Detailed specifications for individual features.

## Process

- [Release Process:](RELEASE.md) Versioning scheme, release steps, Homebrew tap updates.
- [Smoke Testing:](SMOKE_TESTING.md) Manual test matrix covering all codec/container/audio combinations.

## Decisions

- [Decision Records:](decisions/) Architecture Decision Records (ADRs).
