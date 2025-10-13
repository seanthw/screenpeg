#!/bin/bash

# --- Configuration ---
OUTPUT_DIR="." # Directory to save recordings
WEBCAM_DEVICE="/dev/video0" # Your webcam device
AUDIO_SOURCE="default" # PulseAudio source (use `pactl list sources` to find others)

# --- Script Logic ---
clear
echo "========================================"
echo " FFmpeg Screen & Demo Recorder"
echo "========================================"
echo

# 1. Generate a unique filename
FILENAME="$OUTPUT_DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

# 2. Select Resolution
echo "Please select a recording resolution:"
echo " 1) 144p (256x144)"
echo " 2) 240p (426x240)"
echo " 3) 360p (640x360)"
echo " 4) 480p (854x480)"
echo " 5) 720p (1280x720)"
echo " 6) 1080p (1920x1080)"
echo " 7) 2160p/4K (3840x2160)"
echo " 8) Full Screen (Your current resolution)"
echo

read -p "Enter your choice [8]: " resolution_choice
resolution_choice=${resolution_choice:-8} # Default to 8 if empty

case $resolution_choice in
    1) RESOLUTION="256x144" ;;
    2) RESOLUTION="426x240" ;;
    3) RESOLUTION="640x360" ;;
    4) RESOLUTION="854x480" ;;
    5) RESOLUTION="1280x720" ;;
    6) RESOLUTION="1920x1080" ;;
    7) RESOLUTION="3840x2160" ;;
    8) RESOLUTION=$(xdpyinfo | grep dimensions | awk '{print $2;}') ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

# 3. Ask about Microphone
read -p "Record microphone audio? (y/n) [n]: " record_mic
record_mic=${record_mic:-n}

# 4. Ask about Webcam
read -p "Record webcam as picture-in-picture? (y/n) [n]: " record_webcam
record_webcam=${record_webcam:-n}


# 5. Build the ffmpeg command
FFMPEG_CMD="ffmpeg"

# --- Video Inputs ---
# Main screen input
FFMPEG_CMD+=" -f x11grab -s $RESOLUTION -i :0.0"

# Optional webcam input
if [[ "$record_webcam" =~ ^[Yy]$ ]]; then
    FFMPEG_CMD+=" -f v4l2 -i $WEBCAM_DEVICE"
fi

# --- Audio Input ---
if [[ "$record_mic" =~ ^[Yy]$ ]]; then
    FFMPEG_CMD+=" -f pulse -i $AUDIO_SOURCE"
fi

# --- Codecs and Filters ---
# Video codec
FFMPEG_CMD+=" -c:v libx264 -preset ultrafast -pix_fmt yuv420p"

# Audio codec
if [[ "$record_mic" =~ ^[Yy]$ ]]; then
    FFMPEG_CMD+=" -c:a aac -b:a 128k"
fi

# Picture-in-Picture Filtergraph
if [[ "$record_webcam" =~ ^[Yy]$ ]]; then
    # [0:v] is the screen, [1:v] is the webcam
    FFMPEG_CMD+=" -filter_complex '[1:v] scale=320:-1 [pip]; [0:v][pip] overlay=main_w-overlay_w-10:main_h-overlay_h-10'"
fi

# --- Output File ---
FFMPEG_CMD+=" $FILENAME"


# 6. Execute the command
echo
echo "======================================================================"
echo "Starting recording..."
echo "Resolution: $RESOLUTION"
echo "Filename: $FILENAME"
echo
echo ">>> PRESS 'q' IN THIS TERMINAL TO STOP RECORDING <<<"
echo "======================================================================"
echo

# Print the command for debugging
# echo "Running command:"
# echo "$FFMPEG_CMD"

eval $FFMPEG_CMD

echo
echo "========================================"
echo "Recording stopped."
echo "File saved to: $FILENAME"
echo "========================================"
