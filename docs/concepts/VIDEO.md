# Video Concepts

## How Screen Recording Works

A screen recording is a sequence of still images played back fast enough to create the illusion of motion. Each image is called a **frame**. A frame is a grid of pixels, where each pixel stores a color value (and sometimes a transparency value). The dimensions of that grid are the recording's **resolution**, and the number of frames captured per second is the **frame rate**.

Raw frames are large. A single uncompressed frame at 2048x1332 with 4 bytes per pixel is roughly 10 MB. At 60 frames per second, that adds up to about 600 MB every second. To make files practical to store and share, a **codec** compresses the raw pixel data -- trading some combination of quality, file size, and editing flexibility. The compressed video and audio tracks are then wrapped in a **container** (file format) like MOV or MP4.

The sections below explain each of these concepts in detail, along with related settings like bitrate, keyframes, color space, HDR, and transparency.

## Resolution

Resolution is the number of pixels in each frame, expressed as width x height (e.g. 2048x1332). Higher resolution means more detail but larger files and more processing work.

On macOS Retina displays there are two coordinate systems: **logical points** (what System Settings reports, e.g. 1024x666) and **physical pixels** (the actual hardware resolution, typically 2x on Retina). Screen recording apps choose which scale to capture at.

Most codecs require even pixel dimensions. Odd widths or heights are typically rounded up to the nearest even number.

## Frame Rate

Frame rate is the number of frames captured per second (fps). Common values:

- **24 fps** -- Cinematic feel, smallest files.
- **30 fps** -- Standard for most video. Good balance.
- **60 fps** -- Smooth motion, important for UI animations and cursor movement. Doubles file size compared to 30 fps.
- **Native** -- Matches the display's refresh rate (e.g. 120 Hz on ProMotion displays).

Higher frame rates produce smoother playback at the cost of larger files and higher CPU/GPU load during capture.

## Codecs

A codec (coder-decoder) compresses raw pixel data into a storable format. Without compression, screen recordings would be enormous (a 2048x1332 display at 60 fps produces ~10 GB/min of raw data).

### Interframe vs Intraframe

- **Interframe codecs** (H.264, HEVC) store the difference between frames. They produce small files but individual frames depend on surrounding frames, making seeking and editing slower.
- **Intraframe codecs** (ProRes) encode each frame independently. Files are much larger but every frame can be accessed instantly, which makes editing responsive.

### Lossy vs Visually Lossless

- **Lossy** codecs (H.264, HEVC) discard information the encoder decides is imperceptible. Quality depends on bitrate.
- **Visually lossless** codecs (ProRes) preserve enough information that the output is indistinguishable from the source. They use fixed-quality encoding rather than targeting a bitrate.

### Common Codecs

| Codec | Type | Compression | Typical Use |
|-------|------|-------------|-------------|
| H.264 (AVC) | Interframe, lossy | High | Web sharing, maximum compatibility |
| HEVC (H.265) | Interframe, lossy | Very high | Smaller files, modern players |
| ProRes 422 | Intraframe, visually lossless | Low | Professional editing, HDR |
| ProRes 4444 | Intraframe, visually lossless | Low | Compositing, transparency, HDR |

## Bitrate

Bitrate is the amount of data used per second of video, measured in Mbps (megabits per second). It only applies to lossy codecs (H.264, HEVC). Higher bitrate means higher quality and larger files.

Bitrate is typically calculated from the resolution, frame rate, and a quality factor (bits per pixel). HEVC achieves comparable quality to H.264 at roughly half the bitrate due to more efficient compression.

ProRes codecs use fixed-quality encoding and do not have a configurable bitrate.

## Keyframes

A keyframe (I-frame) is a complete frame that does not depend on other frames. Interframe codecs insert keyframes at regular intervals (e.g. every 2 seconds). The space between keyframes contains delta frames (P-frames, B-frames) that only store changes.

More frequent keyframes make seeking faster but increase file size. Less frequent keyframes save space but make random access slower.

## Containers

A container (file format) wraps encoded video and audio tracks into a single file. The container itself does not affect quality -- it determines which codecs and features are allowed inside.

| Container | Extension | Notes |
|-----------|-----------|-------|
| MOV (QuickTime) | `.mov` | Apple's native format. Supports all codecs, alpha, HDR, PCM audio. |
| MP4 (MPEG-4) | `.mp4` | Widely compatible. Limited to H.264/HEVC and AAC audio. No alpha, no HDR. |

## Pixel Format

The pixel format defines how color data is stored in each frame buffer. Two common layouts for screen recording:

- **BGRA 8-bit** -- 4 channels (Blue, Green, Red, Alpha), 8 bits each. Standard for SDR content. Simple packed layout.
- **YCbCr 10-bit (4:2:0)** -- Separates brightness (luma) from color (chroma). 10 bits per component. Chroma is stored at half resolution in both dimensions. Used for HDR content.

The pixel format must match between the capture source and the encoder to avoid unnecessary conversions.

## Color Space and Color Profile

A color space defines the range of colors (gamut) and how numerical values map to visible colors. Key properties:

- **Color primaries** define the gamut (range of reproducible colors). **BT.709** is standard for SDR, covering roughly the sRGB gamut. **BT.2020** is a wider gamut used for HDR.
- **Transfer function** defines how brightness values map to light output. **Gamma** curves are used for SDR. **HLG** (Hybrid Log-Gamma) and **PQ** (Perceptual Quantizer) are used for HDR.
- **Matrix coefficients** define how RGB converts to/from YCbCr. Must match the color primaries (BT.709 matrix for BT.709 primaries, BT.2020 matrix for BT.2020 primaries).

These properties are written as metadata in the video file so players know how to display the content correctly.

## HDR (High Dynamic Range)

HDR captures a wider range of brightness and color than SDR. This requires:

1. **10-bit (or higher) pixel format** -- 8-bit only supports 256 brightness levels; 10-bit supports 1024.
2. **Wide color gamut** (BT.2020) -- Covers more colors than standard BT.709/sRGB.
3. **HDR transfer function** (HLG or PQ) -- Maps the extended brightness range.
4. **A codec that supports it** -- ProRes 422 and ProRes 4444 support 10-bit HDR. H.264 does not. HEVC technically can, but support varies.

HDR content looks like SDR on displays that do not support it. HLG is designed to be backwards-compatible without requiring additional metadata.

## Alpha Channel (Transparency)

The alpha channel stores per-pixel opacity. This is useful when recording a single window and preserving the transparent background for compositing.

Not all codecs support alpha:
- **ProRes 4444** always includes alpha.
- **HEVC with Alpha** supports it in MOV containers only.
- **H.264** and **ProRes 422** do not support alpha.
