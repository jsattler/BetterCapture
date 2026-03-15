# SCStreamConfiguration Reference

How `SCStreamConfiguration` properties map to the video and audio concepts described in [concepts/VIDEO.md](../concepts/VIDEO.md) and [concepts/AUDIO.md](../concepts/AUDIO.md). This is a reference for understanding which settings matter and how they must align between the capture and writing sides.

## Video Configuration

### Resolution

| Property            | Description                                                                            |
| ------------------- | -------------------------------------------------------------------------------------- |
| `width`             | Output width in pixels.                                                                |
| `height`            | Output height in pixels.                                                               |
| `scalesToFit`       | Whether to scale source content to fit the configured dimensions.                      |
| `captureResolution` | `.automatic`, `.best`, or `.nominal`. Controls Retina (2x) vs logical (1x) resolution. |

To capture at native Retina resolution, set `width` and `height` to the physical pixel dimensions (logical points x `pointPixelScale`). The framework does not automatically use Retina resolution -- you must calculate and set the dimensions yourself.

### Frame Rate

| Property               | Description                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------- |
| `minimumFrameInterval` | Minimum time between frames. For 60 fps, set to `CMTime(value: 1, timescale: 60)`. |

This is a _minimum interval_, not a guaranteed frame rate. SCK may deliver frames less frequently if the screen content is static (it skips duplicate frames).

### Pixel Format and Color

| Property         | Description                                                                                                                              |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `pixelFormat`    | Pixel format for output buffers. `kCVPixelFormatType_32BGRA` for SDR. HDR format varies by codec (see [HDR](HDR.md)). |
| `colorSpaceName` | Color space for the output. **Do not set manually for HDR** -- it triggers an internal tone-mapping pass that clips EDR headroom.         |
| `colorMatrix`    | YCbCr matrix. Only supports BT.709/601/240M -- does not support BT.2020. Use HDR presets instead.                                        |

The pixel format must match what the `AVAssetWriterInput` expects. Mismatches cause either conversion overhead or encoding failures.

### HDR / Dynamic Range

| Property              | Description                                                                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------- |
| `captureDynamicRange` | `.sdr`, `.hdrLocalDisplay`, or `.hdrCanonicalDisplay`. Controls whether the stream captures SDR or HDR content. |

**Presets (recommended):** Rather than setting individual HDR properties manually, use an `SCStreamConfiguration` preset that configures dynamic range, pixel format, and color space as a validated unit:

| Preset                                         | macOS | Description                                                       |
| ---------------------------------------------- | ----- | ----------------------------------------------------------------- |
| `.captureHDRRecordingPreservedSDRHDR10`        | 26+   | HDR10 output with correct BT.2020/PQ tags and SDR UI preservation |
| `.captureHDRStreamCanonicalDisplay`            | 15+   | HDR optimized for external display playback (P3/PQ)               |

When using `.captureHDRRecordingPreservedSDRHDR10`, the pixel format for ProRes codecs must be overridden to match their chroma subsampling requirements. For HEVC, the preset's default pixel format should be left unchanged.

For detailed HDR configuration guidance, see [HDR Capture Reference](HDR.md).

### Captured Elements

| Property                    | Description                                                       |
| --------------------------- | ----------------------------------------------------------------- |
| `showsCursor`               | Whether the cursor appears in the captured output.                |
| `shouldBeOpaque`            | If `true`, semi-transparent content renders as opaque (no alpha). |
| `ignoreShadowsDisplay`      | Exclude window shadows when capturing a display.                  |
| `ignoreShadowsSingleWindow` | Exclude window shadows when capturing a single window.            |

### Frame Queue

| Property     | Description                                                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `queueDepth` | Maximum frames held in the output queue. If the consumer (asset writer) falls behind, older frames are dropped. Default is 8. |

A deeper queue provides more buffer against momentary slowdowns but uses more memory.

## Audio Configuration

| Property                      | Description                                      |
| ----------------------------- | ------------------------------------------------ |
| `capturesAudio`               | Enable system audio capture.                     |
| `sampleRate`                  | Audio sample rate in Hz. Default is 48000.       |
| `channelCount`                | Number of audio channels. Default is 2 (stereo). |
| `excludesCurrentProcessAudio` | Exclude audio from the capturing app itself.     |

### Microphone Capture (macOS 15+)

| Property                    | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| `captureMicrophone`         | Enable microphone capture as a separate stream output type (`.microphone`).  |
| `microphoneCaptureDeviceID` | The unique ID of the microphone device to use. `nil` for the system default. |

Microphone audio is delivered through a separate `SCStreamOutput` callback (`.microphone` type), which allows recording it as an independent track.

## Configuration by Codec

Not every codec uses every setting. The table below shows which SCK and AVAssetWriter settings are relevant for each codec.

### SCStreamConfiguration (Capture Side)

| Setting               | H.264      | HEVC                                   | ProRes 422                              | ProRes 4444                             |
| --------------------- | ---------- | -------------------------------------- | --------------------------------------- | --------------------------------------- |
| `pixelFormat`         | BGRA 8-bit | BGRA 8-bit (SDR) or YCbCr 10-bit 4:2:0 (HDR) | BGRA 8-bit (SDR) or YCbCr 10-bit 4:2:2 (HDR) | BGRA 8-bit (SDR) or RGBAHalf 16-bit (HDR) |
| `captureDynamicRange` | `.sdr`     | `.sdr` or HDR preset                  | `.sdr` or HDR preset                   | `.sdr` or HDR preset                   |
| `shouldBeOpaque`      | `true`     | depends on alpha                       | `true`                                  | `false` (alpha always on)               |

### AVAssetWriterInput (Writer Side)

| Setting           | H.264                    | HEVC                     | ProRes 422                         | ProRes 4444                         |
| ----------------- | ------------------------ | ------------------------ | ---------------------------------- | ----------------------------------- |
| Video codec       | `kCMVideoCodecType_H264` | `kCMVideoCodecType_HEVC` | `kCMVideoCodecType_AppleProRes422` | `kCMVideoCodecType_AppleProRes4444` |
| Bitrate           | Calculated from bpp      | Calculated from bpp      | Not set (fixed quality)            | Not set (fixed quality)             |
| Keyframe interval | `frameRate * 2`          | `frameRate * 2`          | Not applicable (intraframe)        | Not applicable (intraframe)         |
| Color properties  | BT.709 (explicit)        | BT.709 (SDR) or BT.2020/PQ via `AVVideoColorPropertiesKey` (HDR) | BT.709 (SDR) or BT.2020/PQ via per-frame `CVBufferSetAttachment` (HDR) | BT.709 (SDR) or BT.2020/PQ via per-frame `CVBufferSetAttachment` (HDR) |
| Container         | MOV or MP4               | MOV or MP4               | MOV only                           | MOV only                            |

### Feature Requirements

| Feature             | Required Configuration                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **HDR**             | HEVC, ProRes 422, or ProRes 4444 + codec-specific HDR pixel format + HDR preset or manual `captureDynamicRange` + BT.2020/PQ color tagging. See [HDR Capture Reference](HDR.md). |
| **Alpha channel**   | HEVC with Alpha or ProRes 4444 + `shouldBeOpaque` set to `false` + MOV container. HEVC alpha is mutually exclusive with HDR.                                         |
| **Even dimensions** | H.264 and HEVC require even pixel width and height. Round up with `ceil(value / 2) * 2`. ProRes does not have this restriction.                                     |

## Mapping to AVAssetWriter

The SCK configuration determines what data arrives in the `CMSampleBuffer` callbacks. The `AVAssetWriter` side must be configured to accept the same formats:

| SCK Property          | AVFoundation Setting                                                  |
| --------------------- | --------------------------------------------------------------------- |
| `pixelFormat`         | `AVAssetWriterInputPixelBufferAdaptor` source pixel format attributes |
| `captureDynamicRange` | `AVVideoColorPropertiesKey` on the video writer input                 |
| `sampleRate`          | `AVSampleRateKey` in audio settings                                   |
| `channelCount`        | `AVNumberOfChannelsKey` in audio settings                             |

If the SCK pixel format is BGRA but the writer expects YCbCr (or vice versa), the system inserts a conversion step that adds latency and CPU load.

## Further Reading

- [HDR Capture Reference](HDR.md) -- Detailed HDR configuration, pitfalls, and encoding constraints.
- [SCStreamConfiguration API Reference](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)
- [AVAssetWriter API Reference](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Tagging Media with Video Color Information](https://developer.apple.com/documentation/avfoundation/tagging-media-with-video-color-information)
