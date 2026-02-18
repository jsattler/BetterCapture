# Glossary

Quick reference for terms used throughout the documentation.

| Term                   | Definition                                                                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ |
| **AAC**                | Advanced Audio Coding. A lossy audio codec.                                                                  |
| **Alpha channel**      | Per-pixel transparency data. Allows compositing over other content.                                          |
| **Bitrate**            | Amount of data per second of media, usually in Mbps (video) or kbps (audio).                                 |
| **BT.709**             | Standard color space for SDR video. Similar gamut to sRGB.                                                   |
| **BT.2020**            | Wide color gamut standard for HDR/UHD video.                                                                 |
| **Chroma subsampling** | Reducing color resolution relative to brightness. 4:2:0 stores chroma at half resolution in both dimensions. |
| **CMSampleBuffer**     | Core Media type that carries a media sample (video frame or audio buffer) with timing information.           |
| **Codec**              | Coder-decoder. Algorithm that compresses and decompresses media data.                                        |
| **Container**          | File format that wraps one or more encoded media tracks (e.g. MOV, MP4).                                     |
| **Frame rate**         | Number of video frames per second (fps).                                                                     |
| **Gamut**              | The range of colors a color space can represent.                                                             |
| **HDR**                | High Dynamic Range. Captures wider brightness and color range than SDR.                                      |
| **HEVC**               | High Efficiency Video Coding (H.265). Interframe lossy codec with better compression than H.264.             |
| **HLG**                | Hybrid Log-Gamma. An HDR transfer function that is backwards-compatible with SDR displays.                   |
| **Interframe**         | Compression that stores differences between frames. Produces small files.                                    |
| **Intraframe**         | Compression that encodes each frame independently. Larger files, faster seeking.                             |
| **Keyframe**           | A complete frame that does not depend on other frames (I-frame).                                             |
| **Luma**               | Brightness component in YCbCr color representation.                                                          |
| **PCM**                | Pulse-Code Modulation. Uncompressed audio format.                                                            |
| **Pixel format**       | How color data is laid out in memory for each pixel (e.g. BGRA 8-bit, YCbCr 10-bit).                         |
| **ProRes**             | Apple's family of intraframe, visually lossless video codecs.                                                |
| **Resolution**         | Pixel dimensions of a video frame (width x height).                                                          |
| **Sample rate**        | Number of audio samples per second, in Hz.                                                                   |
| **SCK**                | ScreenCaptureKit. Apple's framework for capturing screen content on macOS.                                   |
| **SDR**                | Standard Dynamic Range. Conventional brightness and color range.                                             |
| **Transfer function**  | Mathematical curve mapping encoded values to display brightness (e.g. gamma, HLG, PQ).                       |
| **YCbCr**              | Color model separating brightness (Y) from color difference (Cb, Cr). Used in video encoding.                |
