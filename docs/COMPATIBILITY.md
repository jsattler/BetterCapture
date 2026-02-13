# Codec and Container Compatibility

This document describes the compatibility between video/audio codecs, container formats, and feature support in BetterCapture.

## Container Format Support

BetterCapture supports two container formats:

| Container | File Extension | Description |
|-----------|----------------|-------------|
| MOV       | `.mov`         | Apple QuickTime Movie format. Full feature support including ProRes and alpha channels. |
| MP4       | `.mp4`         | MPEG-4 Part 14 format. Wide compatibility but limited codec support. |

## Video Codec Compatibility Matrix

| Video Codec    | MOV | MP4 | Notes |
|----------------|-----|-----|-------|
| H.264          | Yes | Yes | Most compatible codec, no alpha or HDR support |
| H.265 (HEVC)   | Yes | Yes | Better compression than H.264, no alpha in MP4 |
| ProRes 422     | Yes | No  | Professional quality, 10-bit, MOV only |
| ProRes 4444    | Yes | No  | Highest quality, includes alpha channel, MOV only |

## Feature Support by Video Codec

| Video Codec    | Alpha Channel | HDR (10-bit) | Notes |
|----------------|---------------|--------------|-------|
| H.264          | No            | No           | 8-bit SDR only |
| H.265 (HEVC)   | Optional*     | No           | Alpha requires MOV container |
| ProRes 422     | No            | Yes          | 10-bit HDR support |
| ProRes 4444    | Always        | Yes          | 10-bit HDR, always includes alpha |

*HEVC with alpha (`hevcWithAlpha`) is only supported in MOV containers.

## Audio Codec Compatibility Matrix

| Audio Codec | MOV | MP4 | Notes |
|-------------|-----|-----|-------|
| AAC         | Yes | Yes | Compressed audio, good quality |
| PCM         | Yes | No  | Uncompressed audio, MOV only |

## Container Format Restrictions

### MP4 Restrictions

When using MP4 container format:
- **Video codecs limited to:** H.264, HEVC (without alpha)
- **Audio codecs limited to:** AAC
- **No alpha channel support**
- **No HDR support** (codecs that support HDR are not compatible with MP4)

### MOV Capabilities

When using MOV container format:
- All video codecs supported
- All audio codecs supported
- Full alpha channel support (HEVC with alpha, ProRes 4444)
- HDR support with ProRes codecs

## Automatic Settings Adjustment

BetterCapture automatically adjusts settings when changing container formats to maintain compatibility:

1. **When switching to MP4:**
   - If current video codec is ProRes, automatically switches to HEVC
   - If alpha channel is enabled, automatically disables it
   - If audio codec is PCM, automatically switches to AAC

2. **When selecting ProRes codecs:**
   - If container is MP4, automatically switches to MOV

3. **When enabling alpha channel:**
   - Only allowed if both video codec supports alpha AND container is MOV

## Recommended Settings

### For Maximum Compatibility
- Container: MP4
- Video Codec: H.264
- Audio Codec: AAC

### For Professional Quality
- Container: MOV
- Video Codec: ProRes 422 (without alpha) or ProRes 4444 (with alpha)
- Audio Codec: AAC or PCM

### For Good Quality with Reasonable File Size
- Container: MOV or MP4
- Video Codec: HEVC
- Audio Codec: AAC

## Technical References

- [About Apple ProRes (Apple Support HT202410)](https://support.apple.com/en-us/HT202410)
- [TN3104: Recording video in Apple ProRes](https://developer.apple.com/documentation/technotes/tn3104-recording-video-in-apple-prores)
- [HEVC Video with Alpha Interoperability Profile](https://developer.apple.com/av-foundation/HEVC-Video-with-Alpha-Interoperability-Profile.pdf)
