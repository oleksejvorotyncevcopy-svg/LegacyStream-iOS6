# RetroMusic (Music Player)

**RetroMusic** is a custom music player client written in Objective-C using Theos, designed to resurrect music streaming and downloading on legacy iOS 6.1 devices. 

Instead of relying on dead APIs, this project utilizes a combination of a lightweight iOS client (`armv7` / `iphoneos-arm` architecture) and a Python/Flask proxy server. The player searches for music via iTunes and seamlessly pulls the audio stream from YouTube under the hood.

## Features

* **Native Streaming:** The client uses `AVPlayer` for audio playback. The backend server proxies `mp4` streams and properly handles `Range` requests, allowing the legacy `CoreMedia` framework to read files in chunks.
* **Offline Mode (Library):** Any track can be downloaded locally. The file is saved as an `mp4` in the app's `Documents` directory, and its metadata is written to a `library.plist` file.
* **Background Playback:** The player continues to run when the screen is locked—this is achieved by adding the `audio` key to the `UIBackgroundModes` array in the `Info.plist`.
* **Lockscreen Controls:** Full integration with `MPNowPlayingInfoCenter` and `RemoteControlEvents` handling. The play/pause buttons on the lock screen work just like a native iOS app.
* **Custom UI:** A geeky, dark-themed interface built entirely without Storyboards—every view is constructed programmatically in code.

## Tech Stack

* **Frontend (iOS):** Objective-C, Theos Makefile.
* **Apple Frameworks:** `UIKit`, `CoreGraphics`, `AVFoundation`, `Foundation`, `CoreMedia`, `MediaPlayer`.
* **Backend (Server):** Python 3, Flask, `yt-dlp`, `requests`, Node.js (used to bypass YouTube's JS challenges).

---

## Deployment & Build Instructions

### 1. Backend (Server)
The server acts as a bridge between your legacy device and the modern web.
1. Install the required Python dependencies:
   ```bash
   pip install flask requests yt-dlp
   ```
2. Make sure you have `node` installed (the code expects the path `/opt/homebrew/bin/node`), as `yt-dlp` might need it to execute JavaScript challenges.
3. Start the Flask server:
   ```bash
   python server.py
   ```
   *By default, the server listens on port `8080` at `0.0.0.0`.*


### 2. Frontend (Client)
The `com.vorotyntsev.musicplayer` package is built using Theos.
1. Open the `Makefile` and configure your paths. By default, the Theos path is set to `/Users/vorotyntsev/theos`.
2. Set the IP address of your jailbroken device in the `THEOS_DEVICE_IP` variable. The default SSH port is set to `22`.
3. Compile and install the tweak onto your device:
   ```bash
   make package install
   ```

---

## How it Works Under the Hood

1. **Search:** When you type a query, the iOS client sends a GET request to `/search`. The server proxies this to the official `itunes.apple.com/search` API, parses the results, and returns clean JSON containing titles, artists, and cover art to the client.
2. **Fetching the Stream:** When you tap a track, the client hits `/track?id=Artist_Title`. The backend spins up `yt-dlp` using the `ytsearch1:` flag, which finds the most relevant YouTube video and extracts the direct `URL` to the `mp4` audio stream.
3. **Proxying:** The client receives a local proxy link (e.g., `/proxy?vid=...`). When the client requests it, the Flask server streams the audio directly from YouTube to the iPhone, preserving original HTTP headers like `Content-Length` and `Accept-Ranges` to keep `AVPlayer` happy.

## Disclaimer

This project is for **educational and research purposes only**. It serves as a proof-of-concept for legacy protocol interoperability and audio streaming techniques on older hardware.

* **No Affiliation:** This project is not affiliated with, endorsed by, or sponsored by Apple Inc., Google LLC, YouTube, or any other third-party service mentioned.
* **User Responsibility:** The author is not responsible for how you use this software. Users are responsible for complying with the Terms of Service of any third-party APIs or platforms (e.g., YouTube, iTunes) used by this project.
* **Copyright Content:** This software does not host, store, or distribute any copyrighted music files. It only provides a mechanism to stream and download content from public sources.
* **As-Is Basis:** This software is provided "as-is" without warranty of any kind. The author assumes no liability for any damages or issues resulting from the use of this code.

*If you are a copyright holder and have concerns regarding this project, please contact the developer via GitHub.*

Happy Hacking! 
