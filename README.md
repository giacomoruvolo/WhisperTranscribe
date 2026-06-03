# WhisperTranscribe

A native macOS app for **local, offline audio & video transcription**, powered by [OpenAI Whisper](https://github.com/openai/whisper) running on Apple Silicon via [MLX](https://github.com/ml-explore/mlx).

Drop in any audio or video file and get clean subtitles — entirely on your Mac, with nothing uploaded to the cloud.

> **Version 3.0** · macOS 14+ · Apple Silicon only

---

## Features

- 🎙️ **Fully local & offline** — transcription runs on your Mac, no data leaves the device
- 🌍 **Audio language selector** — auto-detect or force a specific spoken language
- 🔤 **Output language** — keep the original language, or translate subtitles to English
- 📄 **Multiple formats** — SRT, VTT, TXT, JSON
- 📚 **Batch queue** — drop multiple files and transcribe them in sequence
- ⚙️ **Advanced settings** — temperature, beam size, initial prompt and more
- 🖥️ **Multiple models** — from `tiny` (fastest) to `large-v3` (best quality)
- 🌐 **Bilingual UI** — automatically Italian on Italian systems, English everywhere else

---

## Requirements

- **Mac with Apple Silicon** (M1, M2, M3 or M4) — `mlx-whisper` runs exclusively on Apple's ARM chips
- **macOS 14.0** or later
- **8 GB RAM** minimum (16 GB recommended for the `large-v3` model)
- [Homebrew](https://brew.sh) and **Python 3** (the app installs the rest for you)

### Tested environment

These are the exact versions the app was built and verified with. Newer versions
generally work too, but if you hit an issue, match these for a known-good setup.

| Component | Version |
|---|---|
| macOS | 26.5.1 (Apple M4 Pro) |
| Xcode | 26.5 |
| Swift | 6.3.2 |
| Homebrew | 5.1.14 |
| ffmpeg | 8.1 |
| Python | 3.14.4 |
| mlx-whisper | 0.4.3 |
| mlx / mlx-metal | 0.31.1 |
| huggingface_hub | 1.7.1 |
| numpy | 2.4.3 |

To pin the exact Python packages, after the app's Setup has run you can install
matching versions into its virtual environment:

```bash
~/whisper-env-mlx/bin/pip install \
  "mlx-whisper==0.4.3" "mlx==0.31.1" "mlx-metal==0.31.1" \
  "huggingface_hub==1.7.1" "numpy==2.4.3"
```

---

## Installation

### Option A — Download the app (recommended)

1. Download `WhisperTranscribe.dmg` from the [latest Release](../../releases/latest).
2. Open the `.dmg` and drag **WhisperTranscribe** into your **Applications** folder.
3. On first launch the **Setup** screen checks your environment and installs the
   missing dependencies (`ffmpeg` via Homebrew, `mlx-whisper` in an isolated Python
   virtual environment) with one click.

> The app is ad-hoc signed. On first launch macOS may warn it's from an
> unidentified developer — right-click the app → **Open** to confirm once.

### Option B — Build from source

```bash
git clone https://github.com/giacomoruvolo/WhisperTranscribe.git
cd WhisperTranscribe
bash build.sh          # builds the .app and a drag-to-Applications .dmg
```

or open `WhisperTranscribe.xcodeproj` in Xcode and build the `WhisperTranscribe` scheme.

---

## How it works

WhisperTranscribe is a SwiftUI front-end — it does not bundle any heavy
dependencies. Instead it orchestrates tools installed in your environment:

- **ffmpeg** decodes the audio/video (installed via Homebrew).
- **mlx-whisper** runs the Whisper model on Apple Silicon, from an isolated
  Python virtual environment at `~/whisper-env-mlx`.
- **Models** are downloaded on demand from the
  [`mlx-community`](https://huggingface.co/mlx-community) collection on Hugging Face
  and cached locally.

---

## Acknowledgments & third-party licenses

This app stands on the shoulders of excellent open-source projects:

| Project | Used for | License |
|---|---|---|
| [OpenAI Whisper](https://github.com/openai/whisper) | Speech-recognition models | MIT |
| [Apple MLX](https://github.com/ml-explore/mlx) / [mlx-whisper](https://github.com/ml-explore/mlx-examples) | On-device inference | Apache-2.0 / MIT |
| [ffmpeg](https://ffmpeg.org) | Audio/video decoding | LGPL-2.1+ |
| [mlx-community](https://huggingface.co/mlx-community) | Pre-converted Whisper models | MIT |

These dependencies are **installed separately** on the user's machine and are not
redistributed with this app.

Special thanks to [@FabioS08](https://github.com/FabioS08) for the contribution. 🙏

---

## License

Released under the [MIT License](LICENSE) — made by [Giacomo Ruvolo](https://github.com/giacomoruvolo).

Questions or bugs? Please open an [Issue](../../issues).
