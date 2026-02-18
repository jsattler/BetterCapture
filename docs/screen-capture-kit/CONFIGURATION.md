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
| `pixelFormat`    | Pixel format for output buffers. `kCVPixelFormatType_32BGRA` for SDR, `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange` for HDR 10-bit. |
| `colorSpaceName` | Color space for the output. e.g. `CGColorSpace.sRGB`, `CGColorSpace.itur_2020`.                                                          |
| `colorMatrix`    | YCbCr matrix. e.g. `kCVImageBufferYCbCrMatrix_ITU_R_709_2`, `kCVImageBufferYCbCrMatrix_ITU_R_2020`.                                      |

The pixel format must match what the `AVAssetWriterInput` expects. Mismatches cause either conversion overhead or encoding failures.

### HDR / Dynamic Range

| Property              | Description                                                                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------- |
| `captureDynamicRange` | `.sdr`, `.hdrLocalDisplay`, or `.hdrCanonicalDisplay`. Controls whether the stream captures SDR or HDR content. |

When set to `.hdrLocalDisplay`, the stream delivers frames with the HDR brightness range of the local display. This pairs with `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange` and BT.2020/HLG color properties on the writer side.

Presets are also available (e.g. `SCStreamConfiguration.Preset.captureHDRStreamLocalDisplay`) that configure multiple properties at once.

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

| Setting               | H.264      | HEVC             | ProRes 422                             | ProRes 4444                            |
| --------------------- | ---------- | ---------------- | -------------------------------------- | -------------------------------------- |
| `pixelFormat`         | BGRA 8-bit | BGRA 8-bit       | BGRA 8-bit (SDR) or YCbCr 10-bit (HDR) | BGRA 8-bit (SDR) or YCbCr 10-bit (HDR) |
| `captureDynamicRange` | `.sdr`     | `.sdr`           | `.sdr` or `.hdrLocalDisplay`           | `.sdr` or `.hdrLocalDisplay`           |
| `shouldBeOpaque`      | `true`     | depends on alpha | `true`                                 | `false` (alpha always on)              |

### AVAssetWriterInput (Writer Side)

| Setting           | H.264                    | HEVC                     | ProRes 422                         | ProRes 4444                         |
| ----------------- | ------------------------ | ------------------------ | ---------------------------------- | ----------------------------------- |
| Video codec       | `kCMVideoCodecType_H264` | `kCMVideoCodecType_HEVC` | `kCMVideoCodecType_AppleProRes422` | `kCMVideoCodecType_AppleProRes4444` |
| Bitrate           | Calculated from bpp      | Calculated from bpp      | Not set (fixed quality)            | Not set (fixed quality)             |
| Keyframe interval | `frameRate * 2`          | `frameRate * 2`          | Not applicable (intraframe)        | Not applicable (intraframe)         |
| Color properties  | Not set (default BT.709) | Not set (default BT.709) | BT.2020 / HLG when HDR             | BT.2020 / HLG when HDR              |
| Container         | MOV or MP4               | MOV or MP4               | MOV only                           | MOV only                            |

### Feature Requirements

| Feature             | Required Configuration                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **HDR**             | ProRes 422 or 4444 + `pixelFormat` set to YCbCr 10-bit + `captureDynamicRange` set to `.hdrLocalDisplay` + color properties set to BT.2020/HLG on the writer input. |
| **Alpha channel**   | HEVC with Alpha or ProRes 4444 + `shouldBeOpaque` set to `false` + MOV container.                                                                                   |
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

- [SCStreamConfiguration API Reference](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)
- [AVAssetWriter API Reference](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Tagging Media with Video Color Information](https://developer.apple.com/documentation/avfoundation/tagging-media-with-video-color-information)
