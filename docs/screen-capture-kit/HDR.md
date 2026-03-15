# HDR Capture Reference

Technical reference for HDR screen capture using ScreenCaptureKit and AVAssetWriter. Covers configuration, encoding constraints, and pitfalls discovered during implementation.

For general HDR concepts, see [concepts/VIDEO.md](../concepts/VIDEO.md). For BetterCapture-specific output settings, see [architecture/OUTPUT.md](../architecture/OUTPUT.md).

## ScreenCaptureKit Configuration

### Presets vs Manual Configuration

ScreenCaptureKit offers two approaches for HDR capture:

**Presets (recommended):** Initialize `SCStreamConfiguration` with a preset that configures dynamic range, pixel format, and color space as a validated unit.

| Preset                                          | macOS | Output Colorimetry          |
| ----------------------------------------------- | ----- | --------------------------- |
| `.captureHDRRecordingPreservedSDRHDR10`         | 26+   | BT.2020 / PQ / BT.2020     |
| `.captureHDRStreamCanonicalDisplay`             | 15+   | P3 D65 / PQ / BT.709       |

The macOS 26+ preset produces correct HDR10 output and preserves the visual appearance of SDR UI elements on HDR screens. It also injects static HDR10 mastering metadata into the stream.

**Manual configuration:** Set `captureDynamicRange` to `.hdrCanonicalDisplay` on a plain `SCStreamConfiguration`. This is the fallback for macOS 15–25. Do **not** set `colorSpaceName` or `colorMatrix` manually (see pitfalls below).

### Pixel Format by Codec

Each codec requires a specific pixel format for HDR. The preset configures a default, but ProRes codecs need an override to match their chroma subsampling:

| Codec       | Pixel Format                                       | FourCC | Bit Depth | Subsampling |
| ----------- | -------------------------------------------------- | ------ | --------- | ----------- |
| HEVC        | `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange` | `x420` | 10-bit    | 4:2:0       |
| ProRes 422  | `kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange` | `x422` | 10-bit    | 4:2:2       |
| ProRes 4444 | `kCVPixelFormatType_64RGBAHalf`                    | `RGhA` | 16-bit    | 4:4:4       |

When using the macOS 26+ preset, override `config.pixelFormat` for ProRes codecs only. For HEVC, leave the preset's default pixel format unchanged to preserve EDR headroom.

### Pitfalls

1. **Do not set `colorSpaceName` for HDR.** Explicitly assigning an HDR color space (e.g. `CGColorSpace.itur_2100_HLG`, `CGColorSpace.itur_2020`) triggers an internal CoreGraphics tone-mapping pass that destructively clips all EDR headroom and caps pixel values at 1.0. Use presets instead.

2. **`colorMatrix` does not support BT.2020.** The property only accepts BT.709, BT.601, and SMPTE 240M values. Setting it has no effect on HDR output. The preset handles this correctly.

3. **Buffer tags are unreliable with manual configuration.** When setting `captureDynamicRange`, `pixelFormat`, and `colorSpaceName` individually, the resulting pixel buffers may have `nil` primaries, `nil` transfer function, and a BT.709 matrix regardless of what was requested. This is why presets are preferred.

4. **8-bit pixel formats cause severe banding.** Always use 10-bit or higher formats for HDR. The standard 8-bit BGRA format only supports 256 brightness levels, which is visibly insufficient for HDR gradients.

## AVAssetWriter Encoding

### HEVC Main 10 (H.265)

HEVC HDR requires specific compression properties to produce valid HDR10 output:

| Setting | Value | Purpose |
| ------- | ----- | ------- |
| `AVVideoCodecKey` | `.hevc` | Not `.hevcWithAlpha` (alpha and HDR are mutually exclusive) |
| `AVVideoProfileLevelKey` | `kVTProfileLevel_HEVC_Main10_AutoLevel` | Enforce 10-bit encoding |
| `kVTCompressionPropertyKey_HDRMetadataInsertionMode` | `kVTHDRMetadataInsertionMode_Auto` | Write HDR10 SEI messages and container metadata |
| `AVVideoColorPropertiesKey` | BT.2020 / PQ / BT.2020 | Tag the `colr` atom and HEVC VUI parameters |

Without the Main 10 profile, VideoToolbox defaults to 8-bit encoding and silently truncates the 10-bit source data from ScreenCaptureKit.

**Do not use `AVVideoProfileLevelKey` with H.264 constants** (e.g. `kVTProfileLevel_HEVC_Main10_AutoLevel` is correct; H.264-style profile constants crash AVAssetWriter when used with HEVC).

### ProRes 422 & 4444

ProRes HDR encoding diverges from HEVC in how color metadata is applied:

- **Do not set `AVVideoColorPropertiesKey`.** AVAssetWriter prohibits automatic color matching for the high-bit-depth pixel formats ProRes uses. Setting it causes an error.
- **Do not set `AVVideoScalingModeKey`.** Same restriction applies.
- **Inject color metadata per-frame** using `CVBufferSetAttachment` on each `CVPixelBuffer`:

| Attachment Key                       | Value                                           |
| ------------------------------------ | ----------------------------------------------- |
| `kCVImageBufferColorPrimariesKey`    | `kCVImageBufferColorPrimaries_ITU_R_2020`       |
| `kCVImageBufferTransferFunctionKey`  | `kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ` |
| `kCVImageBufferYCbCrMatrixKey`       | `kCVImageBufferYCbCrMatrix_ITU_R_2020`          |

Use `kCVAttachmentMode_ShouldPropagate` so the tags propagate through the encoding pipeline and are written as `colr`/`nclx` atoms in the output file.

## Buffer Validation

Empty or structural `CMSampleBuffer` payloads will crash the encoder. Before appending any buffer:

1. Extract the attachment array via `CMSampleBufferGetSampleAttachmentsArray`.
2. Parse the `SCStreamFrameInfo.status` key.
3. Verify the status is `SCFrameStatus.complete`.

Only complete frames should be appended to the writer.

## Verification

HDR output can be verified using `ffmpeg` and `mediainfo`:

```bash
# Verify decoded stream properties (codec, bit depth, color tags)
ffmpeg -i recording.mov -frames:v 1 -f rawvideo -y /dev/null

# Cross-check with mediainfo
mediainfo recording.mov | grep -E "Color primaries|Transfer char|Matrix coef|HDR|Bit depth"
```

Expected output for valid HDR10:

| Property          | HEVC                | ProRes 422          | ProRes 4444           |
| ----------------- | ------------------- | ------------------- | --------------------- |
| Pixel format      | `yuv420p10le`       | `yuv422p10le`       | `yuva444p12le`        |
| Color primaries   | `bt2020`            | `bt2020`            | `bt2020`              |
| Transfer function | `smpte2084`         | `smpte2084`         | `smpte2084`           |
| Matrix            | `bt2020nc`          | `bt2020nc`          | `bt2020nc`            |
| Profile           | Main 10             | Standard/HQ         | 4444                  |

The verification script `Scripts/verify_recording.sh` automates these checks for all supported codec/HDR combinations.

## Further Reading

- [Tagging Media with Video Color Information](https://developer.apple.com/documentation/avfoundation/tagging-media-with-video-color-information)
- [SCStreamConfiguration API Reference](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)
- [SMPTE ST 2084 (PQ) Transfer Function](https://en.wikipedia.org/wiki/Perceptual_quantizer)
- [HDR10 Media Profile](https://en.wikipedia.org/wiki/HDR10)
