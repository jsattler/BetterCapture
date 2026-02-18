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

| Codec       | Container | Alpha               | HDR (10-bit) | Notes                                    |
| ----------- | --------- | ------------------- | ------------ | ---------------------------------------- |
| H.264       | MOV, MP4  | No                  | No           | 8-bit SDR only                           |
| HEVC        | MOV, MP4  | Optional (MOV only) | No           | Default codec. Alpha via `hevcWithAlpha` |
| ProRes 422  | MOV only  | No                  | Yes          | 10-bit HDR support                       |
| ProRes 4444 | MOV only  | Always              | Yes          | 10-bit HDR, always includes alpha        |

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

## Pixel Format

### SDR (default)

- **Pixel format:** `kCVPixelFormatType_32BGRA` (32-bit BGRA)
- **Bit depth:** 8 bits per channel (Blue, Green, Red, Alpha)
- **Layout:** Packed, interleaved. Each pixel is 4 bytes in BGRA order.
- **Dynamic range:** `.sdr`
- Used by H.264, HEVC, and ProRes codecs when HDR is off.

### HDR (ProRes only)

- **Pixel format:** `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange` (10-bit 4:2:0 YCbCr)
- **Bit depth:** 10 bits per component
- **Layout:** Biplanar. Luma (Y) plane at full resolution, chroma (CbCr) plane at half resolution in both dimensions (4:2:0 subsampling).
- **Range:** Video range (narrow range, 64-940 for 10-bit luma)
- **Dynamic range:** `.hdrLocalDisplay`
- Used by ProRes 422 and ProRes 4444 when HDR is enabled.

The same pixel format is configured in both the `SCStreamConfiguration` (capture side) and the `AVAssetWriterInputPixelBufferAdaptor` (encoding side) to avoid unnecessary format conversions.

## Color Profile

Color properties are only written explicitly for HDR recordings. SDR recordings rely on the system default color handling (typically BT.709 for H.264 and HEVC).

When HDR is enabled with a ProRes codec, the following color properties are attached to the video track via `AVVideoColorPropertiesKey`:

| Property          | Value                                    | Meaning                               |
| ----------------- | ---------------------------------------- | ------------------------------------- |
| Color primaries   | `AVVideoColorPrimaries_ITU_R_2020`       | BT.2020 wide color gamut              |
| Transfer function | `AVVideoTransferFunction_ITU_R_2100_HLG` | Hybrid Log-Gamma (HLG)                |
| YCbCr matrix      | `AVVideoYCbCrMatrix_ITU_R_2020`          | BT.2020 non-constant luminance matrix |

This combination (BT.2020 + HLG) is chosen because:

- HLG is backwards-compatible with SDR displays (no tone mapping metadata required).
- BT.2020 covers the wide color gamut available on Apple displays.
- It matches the `hdrLocalDisplay` dynamic range mode used by ScreenCaptureKit.

Players and editors must support BT.2020/HLG to display the HDR content correctly. On macOS, QuickTime Player and Final Cut Pro handle this natively.

## HDR

HDR recording is available with ProRes 422 and ProRes 4444 only. When enabled:

- Pixel format switches from 8-bit BGRA to 10-bit YCbCr (see [Pixel Format](#pixel-format) above).
- The stream captures with `hdrLocalDisplay` dynamic range.
- Color properties are set to BT.2020/HLG (see [Color Profile](#color-profile) above).

H.264 and HEVC use 8-bit SDR in all cases.

## Recommended Settings

**General screen recording (default):** HEVC, High quality, 60 fps, MOV. Good balance of quality and file size.

**Smallest file size:** HEVC, Low quality, 30 fps. Suitable for long recordings or when storage is limited.

**Maximum compatibility:** H.264, High quality, 30 fps, MP4. Plays anywhere without transcoding.

**Post-production / editing:** ProRes 422, 60 fps, MOV. Intraframe encoding makes editing responsive. Use ProRes 4444 if transparency is needed.

**HDR content:** ProRes 422 or ProRes 4444, HDR enabled, MOV. Required for 10-bit wide color gamut capture.

## Technical References

- [About Apple ProRes (Apple Support HT202410)](https://support.apple.com/en-us/HT202410)
- [TN3104: Recording video in Apple ProRes](https://developer.apple.com/documentation/technotes/tn3104-recording-video-in-apple-prores)
- [HEVC Video with Alpha Interoperability Profile](https://developer.apple.com/av-foundation/HEVC-Video-with-Alpha-Interoperability-Profile.pdf)
- [AVFoundation Video Settings](https://developer.apple.com/documentation/avfoundation/video-settings)
