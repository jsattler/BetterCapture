# Output Settings

BetterCapture-specific output configuration: how resolution, bitrate, codecs, pixel formats, and color profiles are implemented. For general background on these concepts, see [concepts/VIDEO.md](../concepts/VIDEO.md) and [concepts/AUDIO.md](../concepts/AUDIO.md).

## Resolution

BetterCapture always captures at the native (Retina) pixel resolution. It reads `SCContentFilter.pointPixelScale` (or `NSScreen.backingScaleFactor` as a fallback) and multiplies the logical dimensions by that factor. A display set to 1024x666 produces a 2048x1332 video.

Dimensions are snapped to even pixel counts (`ceil(value / 2) * 2`) for H.264 and HEVC codec compatibility.

## Bitrate

Bitrate applies to H.264 and HEVC only. ProRes codecs use fixed-quality encoding and ignore this setting.

The target average bitrate is calculated as:

```
bitrate = width * height * bitsPerPixel * frameRate
```

### Bits-per-pixel values by quality preset

| Quality | H.264 bpp | HEVC bpp |
| ------- | --------- | -------- |
| Low     | 0.05      | 0.03     |
| Medium  | 0.10      | 0.06     |
| High    | 0.20      | 0.10     |

HEVC uses lower bpp values because it achieves comparable visual quality at roughly half the bitrate of H.264.

## Codec Support

### Video Codecs

| Codec       | Container | Alpha               | HDR (10-bit) | Notes                                                                  |
| ----------- | --------- | ------------------- | ------------ | ---------------------------------------------------------------------- |
| H.264       | MOV, MP4  | No                  | No           | 8-bit SDR only                                                         |
| HEVC        | MOV, MP4  | Optional (MOV only) | Yes          | Default codec. Alpha via `hevcWithAlpha` (mutually exclusive with HDR) |
| ProRes 422  | MOV only  | No                  | Yes          | 10-bit HDR support                                                     |
| ProRes 4444 | MOV only  | Always              | Yes          | 10-bit/12-bit HDR, always includes alpha                               |

### Audio Codecs

| Codec | MOV | MP4 | Notes                    |
| ----- | --- | --- | ------------------------ |
| AAC   | Yes | Yes | Compressed, good quality |
| PCM   | Yes | No  | Uncompressed, MOV only   |

### Automatic Settings Adjustment

BetterCapture automatically adjusts settings when changing formats to maintain compatibility:

1. **When switching to MP4:**
   - If video codec is ProRes, switches to HEVC.
   - If alpha channel is enabled, disables it.
   - If audio codec is PCM, switches to AAC.

2. **When selecting ProRes codecs:**
   - If container is MP4, switches to MOV.

3. **When enabling alpha channel:**
   - Only allowed if the video codec supports alpha AND the container is MOV.
   - HEVC alpha and HDR are mutually exclusive. Enabling one disables the other.

4. **When enabling HDR:**
   - HEVC alpha is disabled (Main 10 profile is incompatible with `hevcWithAlpha`).

## Pixel Format

### SDR (default)

- **Pixel format:** `kCVPixelFormatType_32BGRA` (32-bit BGRA)
- **Bit depth:** 8 bits per channel (Blue, Green, Red, Alpha)
- **Layout:** Packed, interleaved. Each pixel is 4 bytes in BGRA order.
- **Dynamic range:** `.sdr`
- Used by H.264, HEVC, and ProRes codecs when HDR is off.

### HDR

Each codec uses a different pixel format for HDR to match its chroma subsampling and bit-depth requirements:

| Codec       | Pixel Format                                       | Bit Depth | Chroma Subsampling |
| ----------- | -------------------------------------------------- | --------- | ------------------ |
| HEVC        | `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange` | 10-bit    | 4:2:0              |
| ProRes 422  | `kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange` | 10-bit    | 4:2:2              |
| ProRes 4444 | `kCVPixelFormatType_64RGBAHalf`                    | 16-bit    | 4:4:4 (RGBA)       |

All HDR formats use video range (narrow range, 64-940 for 10-bit luma). The pixel format is configured identically on both the `SCStreamConfiguration` (capture side) and the `AVAssetWriterInputPixelBufferAdaptor` (encoding side) to avoid unnecessary format conversions.

## Color Profile

### SDR

SDR recordings are explicitly tagged with BT.709 color properties via `AVVideoColorPropertiesKey` to ensure the output file contains correct `colr` atoms and VUI parameters. Without explicit tags, players may report the color space as "unknown".

| Property          | Value                                 | Meaning           |
| ----------------- | ------------------------------------- | ----------------- |
| Color primaries   | `AVVideoColorPrimaries_ITU_R_709_2`   | BT.709 (standard) |
| Transfer function | `AVVideoTransferFunction_ITU_R_709_2` | BT.709 gamma      |
| YCbCr matrix      | `AVVideoYCbCrMatrix_ITU_R_709_2`      | BT.709 matrix     |

### HDR

All HDR recordings use BT.2020 primaries with PQ (Perceptual Quantizer) transfer function, producing HDR10-compatible output. The color tagging strategy differs by codec:

**HEVC HDR** — Color properties are set via `AVVideoColorPropertiesKey` in the video output settings. The encoder writes the correct `colr` atom and HEVC VUI parameters.

**ProRes HDR** — `AVVideoColorPropertiesKey` must be omitted. AVAssetWriter prohibits automatic color matching for the high-bit-depth pixel formats ProRes uses. Instead, BT.2020/PQ colorimetry is injected per-frame via `CVBufferSetAttachment` on each `CVPixelBuffer`.

| Property          | Value                                      | Meaning                               |
| ----------------- | ------------------------------------------ | ------------------------------------- |
| Color primaries   | `AVVideoColorPrimaries_ITU_R_2020`         | BT.2020 wide color gamut              |
| Transfer function | `AVVideoTransferFunction_SMPTE_ST_2084_PQ` | PQ (Perceptual Quantizer, HDR10)      |
| YCbCr matrix      | `AVVideoYCbCrMatrix_ITU_R_2020`            | BT.2020 non-constant luminance matrix |

This combination (BT.2020 + PQ) is the standard HDR10 signaling. It is recognized by YouTube, QuickTime Player, Final Cut Pro, and other HDR-aware players and services.

## HDR

HDR recording is available with HEVC, ProRes 422, and ProRes 4444. When enabled:

- Pixel format switches from 8-bit BGRA to a codec-specific HDR format (see [Pixel Format](#pixel-format) above).
- Color properties are set to BT.2020/PQ (see [Color Profile](#color-profile) above).
- ScreenCaptureKit is configured via an HDR preset (see [HDR Presets](#hdr-presets) below).

H.264 does not support HDR. HEVC HDR is mutually exclusive with alpha channel capture.

### HDR Presets

BetterCapture uses the `HDRPreset` enum to select the correct ScreenCaptureKit configuration:

| Preset               | macOS Version | SCStreamConfiguration                                                  | Notes                                              |
| -------------------- | ------------- | ---------------------------------------------------------------------- | -------------------------------------------------- |
| `.hdr10PreservedSDR` | 26+           | `SCStreamConfiguration(preset: .captureHDRRecordingPreservedSDRHDR10)` | Automates HDR10 setup, preserves SDR UI appearance |
| `.hdr10Manual`       | 15            | Manual: `captureDynamicRange = .hdrCanonicalDisplay`                   | Manual pixel format and dynamic range              |
| `.sdr`               | Any           | Default `SCStreamConfiguration()`                                      | 8-bit BGRA, SDR                                    |

The macOS 26+ preset injects static HDR10 metadata and configures all color properties as a validated unit. On older macOS versions, BetterCapture manually configures `captureDynamicRange` and the codec-appropriate pixel format.

### HEVC HDR Encoding

HEVC HDR requires additional compression properties to produce valid HDR10 output:

- `AVVideoProfileLevelKey` set to `kVTProfileLevel_HEVC_Main10_AutoLevel` to enforce 10-bit encoding.
- `kVTCompressionPropertyKey_HDRMetadataInsertionMode` set to `kVTHDRMetadataInsertionMode_Auto` to write HDR10 SEI messages and container metadata.

Without the Main 10 profile, VideoToolbox may default to 8-bit encoding and silently truncate the 10-bit source data.

## Recommended Settings

**General screen recording (default):** HEVC, High quality, 60 fps, MOV. Good balance of quality and file size.

**Smallest file size:** HEVC, Low quality, 30 fps. Suitable for long recordings or when storage is limited.

**Maximum compatibility:** H.264, High quality, 30 fps, MP4. Plays anywhere without transcoding.

**Post-production / editing:** ProRes 422, 60 fps, MOV. Intraframe encoding makes editing responsive. Use ProRes 4444 if transparency is needed.

**HDR content:** HEVC or ProRes 422/4444, HDR enabled, MOV. HEVC HDR produces the best balance of quality and file size. ProRes HDR is preferred for post-production workflows.

## Technical References

- [HDR Capture Reference](../screen-capture-kit/HDR.md) -- ScreenCaptureKit HDR configuration, pitfalls, and encoding constraints.
- [About Apple ProRes (Apple Support HT202410)](https://support.apple.com/en-us/HT202410)
- [TN3104: Recording video in Apple ProRes](https://developer.apple.com/documentation/technotes/tn3104-recording-video-in-apple-prores)
- [HEVC Video with Alpha Interoperability Profile](https://developer.apple.com/av-foundation/HEVC-Video-with-Alpha-Interoperability-Profile.pdf)
- [AVFoundation Video Settings](https://developer.apple.com/documentation/avfoundation/video-settings)
