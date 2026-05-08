# RetroMusic (Music Player)

**RetroMusic** is a custom music player client written in Objective-C using Theos, designed to resurrect music streaming and downloading on legacy iOS 6.1 devices.

Instead of relying on dead APIs, this project utilizes a combination of a lightweight iOS client (`armv7` / `iphoneos-arm` architecture) and a Python/Flask proxy server. The player searches for music via iTunes and seamlessly pulls the audio stream from YouTube under the hood, **and now also features full integration with personal Airsonic/Subsonic media servers.**

## Features

* **Dual-Source Streaming:** Toggle instantly between global internet searches (via YouTube) and your personal, self-hosted lossless media library (via Airsonic).
* **Native Playback & Transcoding:** The client uses `AVPlayer` for audio playback. The backend server proxies YouTube `mp4` streams and forces on-the-fly `mp3` transcoding for Airsonic streams, perfectly serving chunks via `Range` requests for legacy `CoreMedia` compatibility.
* **Offline Mode (Library):** Any track from any source can be downloaded locally. The file is saved directly to the app's `Documents` directory with the correct extension, and its metadata is written to a `library.plist` file.
* **Background Playback:** The player continues to run when the screen is locked—this is achieved by adding the `audio` key to the `UIBackgroundModes` array in the `Info.plist`.
* **Lockscreen Controls:** Full integration with `MPNowPlayingInfoCenter` and `RemoteControlEvents` handling. The play/pause buttons on the lock screen work just like a native iOS app.
* **Custom UI:** A geeky, dark-themed interface built entirely without Storyboards—every view is constructed programmatically in code.

## Tech Stack

* **Frontend (iOS):** Objective-C, Theos Makefile.
* **Apple Frameworks:** `UIKit`, `CoreGraphics`, `AVFoundation`, `Foundation`, `CoreMedia`, `MediaPlayer`.
* **Backend (Server):** Python 3, Flask, `yt-dlp`, `requests`, Node.js (used to bypass YouTube's JS challenges).
* **Media Server API:** Subsonic REST API (v1.15.0).

---

## Deployment & Build Instructions

### 1. Backend (Server)

The server acts as a bridge between your legacy device and the modern web.

1. Install the required Python dependencies:
```bash
pip install -r requirements.txt

```


*(Make sure `flask`, `requests`, and `yt-dlp` are installed).*
2. **Configure Airsonic:** Open `server.py` and input your Subsonic API credentials (`SS_URL`, `SS_USER`, `SS_PASS`).
3. Make sure you have `node` installed (the code expects the path `/opt/homebrew/bin/node`), as `yt-dlp` might need it to execute JavaScript challenges.
4. Start the Flask server:
```bash
python3 server.py

```


*By default, the server listens on port `8080` at `0.0.0.0`.*

### 2. Frontend (Client)

The `com.vorotyntsev.musicplayer` package is built using Theos.

1. Open the `Makefile` and configure your paths. By default, the Theos path is set to `/Users/vorotyntsev/theos`.
2. Open `XXRootViewController.m` and set the IP address of your Python server in the `self.serverIP` variable.
3. Set the IP address of your jailbroken device in the `THEOS_DEVICE_IP` variable.
4. Compile and install the tweak onto your device:
```bash
make clean package install

```



---

## How it Works Under the Hood

1. **Global Search (YouTube):** When you type a query in the YouTube tab, the iOS client hits `/search`. The server proxies this to the `itunes.apple.com` API, returning clean JSON. When a track is tapped, the backend uses `yt-dlp` to extract the direct `URL` to the `mp4` audio stream.
2. **Personal Search (Airsonic):** When using the Airsonic tab, the server generates dynamic MD5 auth tokens and securely queries your personal media server using the Subsonic API.
3. **Proxying & Transcoding:** The client receives a local proxy link. When requested, the Flask server streams the audio directly to the iPhone. For Airsonic, it explicitly requests an `mp3` transcode from the server (using `ffmpeg`), ensuring seamless playback and eliminating metadata/format issues on iOS 6.

## Disclaimer

This project is for **educational and research purposes only**. It serves as a proof-of-concept for legacy protocol interoperability and audio streaming techniques on older hardware.

* **No Affiliation:** This project is not affiliated with, endorsed by, or sponsored by Apple Inc., Google LLC, YouTube, Airsonic, or any other third-party service mentioned.
* **User Responsibility:** The author is not responsible for how you use this software. Users are responsible for complying with the Terms of Service of any third-party APIs or platforms used by this project.
* **Copyright Content:** This software does not host, store, or distribute any copyrighted music files. It only provides a mechanism to stream and download content from public sources or the user's private self-hosted server.
* **As-Is Basis:** This software is provided "as-is" without warranty of any kind. The author assumes no liability for any damages or issues resulting from the use of this code.

*If you are a copyright holder and have concerns regarding this project, please contact the developer via GitHub.*

Happy Hacking!
