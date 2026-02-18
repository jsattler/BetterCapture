# Audio Concepts

A brief primer on the audio concepts relevant to screen recording. This covers what each setting controls and why it matters.

## Audio Sources in Screen Recording

Screen recording typically involves two distinct audio sources:

- **System audio:** Sound output from applications (music, video playback, UI sounds, etc.). Captured directly from the audio output stream without going through a microphone.
- **Microphone audio:** Input from a physical or virtual microphone. Used for voiceover, narration, or commentary.

These sources can be recorded as separate tracks in the same file, which allows independent editing in post-production (e.g. adjusting voiceover volume without affecting system audio).

## Sample Rate

Sample rate is the number of audio samples captured per second, measured in Hz or kHz. Each sample is a snapshot of the audio waveform's amplitude at that instant.

- **44.1 kHz:** CD quality. Sufficient for most content.
- **48 kHz:** Standard for video production. The default for screen recording on macOS.

Higher sample rates capture higher frequencies (up to half the sample rate, per the Nyquist theorem), but 48 kHz already covers the full range of human hearing (~20 kHz).

## Bit Depth

Bit depth is the number of bits used to represent each audio sample. Higher bit depth means more precision in amplitude (loudness) levels.

- **16-bit:** -- 65,536 levels. CD quality. ~96 dB dynamic range.
- **24-bit:** 16.7 million levels. Professional audio. ~144 dB dynamic range.
- **32-bit float:** Virtually unlimited dynamic range. Used internally by audio processing pipelines; rarely needed for final output.

For screen recording, 16-bit is typically sufficient. Professional workflows may prefer 24-bit for additional headroom during editing.

## Channels

Audio channels determine the spatial layout of the audio signal.

- **Mono (1 channel):** Single channel. Typical for microphone input.
- **Stereo (2 channels):** Left and right. Standard for system audio output.

Screen recording apps often record system audio in stereo and microphone input as a separate track (mono or stereo depending on the device).

## Audio Codecs

An audio codec compresses raw audio samples into a storable format.

### AAC (Advanced Audio Coding)

- Lossy compression. Discards audio data the encoder considers inaudible.
- Good quality at reasonable file sizes (typically 128-256 kbps for stereo).
- Universally compatible. Works in both MOV and MP4 containers.
- The standard choice for screen recordings intended for sharing.

### PCM (Pulse-Code Modulation)

- Uncompressed. Every sample is stored exactly as captured.
- Large files (stereo 48 kHz 16-bit PCM produces ~11.5 MB/min).
- No quality loss. Useful for professional editing workflows.
- Only supported in MOV containers, not MP4.

### Comparison

| Property     | AAC                  | PCM                  |
| ------------ | -------------------- | -------------------- |
| Compression  | Lossy                | None                 |
| File size    | Small                | Large                |
| Quality loss | Minimal (perceptual) | None                 |
| MOV support  | Yes                  | Yes                  |
| MP4 support  | Yes                  | No                   |
| Best for     | Sharing, general use | Professional editing |

## Latency and Synchronization

Audio and video must stay synchronized throughout the recording. Audio samples arrive at a different rate and cadence than video frames, so the recording pipeline timestamps both streams against a shared clock and interleaves them correctly when writing to disk.

Drift between audio and video (lip sync issues) typically results from clock mismatches, dropped frames, or buffer overflow. A well-designed recording pipeline handles this by using the same synchronization clock for both streams.
