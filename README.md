# ScreenPeg

This directory contains a script for recording screen demos for the project.

## screenpeg.sh

A `bash` script that uses `ffmpeg` to record the screen, with options for different resolutions, audio, and webcam overlays.

### Features

*   **Cross-Platform:** Automatically detects and supports both X11 and Wayland display servers.
*   **Flexible Resolutions:** Choose from a range of standard resolutions or record at your native screen resolution.
*   **Custom Output Directory:** Specify any directory to save your recordings. The script will even create the directory for you if it doesn't exist.
*   **Audio Recording:** Optionally capture audio from your microphone.
*   **Webcam Overlay:** Optionally include a picture-in-picture webcam feed in your recording.
*   **Configurable Output:** Choose your preferred container format (MP4, MKV, or MOV) and enjoy descriptive filenames (`screenpeg-rec_<date time>.<extension>`).
*   **Robust Command Building:** Uses a bash array to construct the `ffmpeg` command, preventing common quoting and parsing errors.