#!/bin/bash

# --- Configuration ---
OUTPUT_DIR="." # Directory to save recordings
WEBCAM_DEVICE="/dev/video0" # Your webcam device
AUDIO_SOURCE="default" # PulseAudio source (use `pactl list sources` to find others)

# --- Auto-detect Session Type ---
SESSION_TYPE=${XDG_SESSION_TYPE:-"x11"}

# --- Check for Wayland dependencies ---
if [ "$SESSION_TYPE" = "wayland" ]; then
    if ! command -v wf-recorder &> /dev/null
    then
        echo "Error: wf-recorder is required for screen recording on Wayland." >&2
        echo "Please install it (e.g., 'sudo pacman -S wf-recorder' on Arch Linux). Exiting." >&2
        exit 1
    fi
fi

# --- Script Logic ---
clear
echo "========================================"
echo " FFmpeg Screen & Demo Recorder"
echo "========================================"
echo "Detected session type: $SESSION_TYPE"
echo

# 1. Select Output Directory
read -p "Enter the output directory [.] (current directory): " OUTPUT_DIR
OUTPUT_DIR=${OUTPUT_DIR:-.} # Default to current directory if empty

# Create directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    read -p "Directory '$OUTPUT_DIR' does not exist. Create it? (y/n) [y]: " create_dir
    create_dir=${create_dir:-y}
    if [[ "$create_dir" =~ ^[Yy]$ ]]; then
        mkdir -p "$OUTPUT_DIR" || { echo "Failed to create directory. Exiting."; exit 1; }
        echo "Directory created: $OUTPUT_DIR"
    else
        echo "Output directory not found. Exiting."
        exit 1
    fi
fi
echo

# 2. Generate a unique filename
echo "Please select an OUTPUT format:"
echo " 1) .mp4 (Default)"
echo " 2) .mkv"
echo " 3) .mov"
echo
read -p "Enter your choice [1]: " format_choice
format_choice=${format_choice:-1} # Default to 1 if empty

case $format_choice in
    1) FILE_EXTENSION="mp4" ;;
    2) FILE_EXTENSION="mkv" ;;
    3) FILE_EXTENSION="mov" ;;
    *) echo "Invalid choice. Using default .mp4"; FILE_EXTENSION="mp4" ;;
esac

FILENAME="$OUTPUT_DIR/screenpeg-rec_$(date +%Y-%m-%d_%H-%M-%S).$FILE_EXTENSION"

# 3. Select Resolution
echo "Please select an OUTPUT resolution:"
echo " 1) 144p (256x144)"
echo " 2) 240p (426x240)"
echo " 3) 360p (640x360)"
echo " 4) 480p (854x480)"
echo " 5) 720p (1280x720)"
echo " 6) 1080p (1920x1080)"
echo " 7) 2160p/4K (3840x2160)"
echo " 8) Full Screen (Native resolution, no scaling)"
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
    8) RESOLUTION="fullscreen" ;; # Special keyword for no scaling
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

# 3. Ask about Microphone
read -p "Record microphone audio? (y/n) [n]: " record_mic
record_mic=${record_mic:-n}

# 4. Ask about Webcam
read -p "Record webcam as picture-in-picture? (y/n) [n]: " record_webcam
record_webcam=${record_webcam:-n}


# 5. Build the ffmpeg command
FFMPEG_ARGS=()

# --- Video Inputs ---
if [ "$SESSION_TYPE" = "wayland" ]; then
    # Use a named pipe for wf-recorder output to ffmpeg
    PIPE_NAME="/tmp/screenpeg-pipe.$$"
    trap 'rm -f "$PIPE_NAME"' EXIT
    mkfifo "$PIPE_NAME"
    FFMPEG_ARGS+=( -y -f matroska -i "$PIPE_NAME" )
else
    # X11: Use x11grab. Capture at native resolution.
    X11_RES=$(xdpyinfo | grep dimensions | awk '{print $2;}')
    FFMPEG_ARGS+=( -f x11grab -framerate 30 -s "$X11_RES" -i :0.0 )
fi

# Optional webcam input
if [[ "$record_webcam" =~ ^[Yy]$ ]]; then
    FFMPEG_ARGS+=( -f v4l2 -i "$WEBCAM_DEVICE" )
fi

# --- Audio Input ---
if [[ "$record_mic" =~ ^[Yy]$ ]]; then
    FFMPEG_ARGS+=( -f pulse -i "$AUDIO_SOURCE" )
fi

# --- Codecs and Filters ---
VIDEO_FILTERS=""

# Scaling filter
if [ "$RESOLUTION" != "fullscreen" ]; then
    VIDEO_FILTERS+="scale=$RESOLUTION"
fi

# Picture-in-Picture Filtergraph
if [[ "$record_webcam" =~ ^[Yy]$ ]]; then
    if [ -n "$VIDEO_FILTERS" ]; then
        # If we are already scaling, chain the filters
        VIDEO_FILTERS="[0:v]${VIDEO_FILTERS}[scaled]; [1:v]scale=320:-1[pip]; [scaled][pip]overlay=main_w-overlay_w-10:main_h-overlay_h-10"
    else
        # No other filters, just do the overlay
        VIDEO_FILTERS="[1:v]scale=320:-1[pip]; [0:v][pip]overlay=main_w-overlay_w-10:main_h-overlay_h-10"
    fi
    FFMPEG_ARGS+=( -filter_complex "$VIDEO_FILTERS" )
elif [ -n "$VIDEO_FILTERS" ]; then
    # Only scaling filter is present
    FFMPEG_ARGS+=( -vf "$VIDEO_FILTERS" )
fi

# Video codec
ENCODER_INFO="libx264 (CPU)"
FFMPEG_ARGS+=( -c:v libx264 -preset ultrafast -pix_fmt yuv420p )

# Audio codec
if [[ "$record_mic" =~ ^[Yy]$ ]]; then
    FFMPEG_ARGS+=( -c:a aac -b:a 128k )
fi

# --- Output File ---
FFMPEG_ARGS+=( "$FILENAME" )


# 6. Execute the command
echo
echo "======================================================================"
echo "Starting recording..."
if [ "$RESOLUTION" = "fullscreen" ]; then
    echo "Resolution: Native Fullscreen"
else
    echo "Resolution: $RESOLUTION"
fi
echo "Encoder: $ENCODER_INFO"
echo "Filename: $FILENAME"
echo
if [[ "$record_webcam" =~ ^[Yy]$ ]]; then
    echo ">>> Please note: Webcam may take a moment to initialize. <<< "
fi
echo ">>> A desktop dialog may appear asking for screen sharing permission. <<< "
echo ">>> PRESS 'q' OR 'Ctrl+C' IN THIS TERMINAL TO STOP RECORDING <<< "
echo "======================================================================"
echo

if [ "$SESSION_TYPE" = "wayland" ]; then
    # Start wf-recorder writing to the pipe in the background
    WF_RECORDER_ARGS=()
    if [ "$RESOLUTION" != "fullscreen" ]; then
        WF_RECORDER_ARGS+=( -g "$RESOLUTION" )
    fi
    wf-recorder "${WF_RECORDER_ARGS[@]}" --muxer=matroska -f "$PIPE_NAME" & 
    WF_RECORDER_PID=$!

    # ffmpeg reads from the pipe (which is already in FFMPEG_ARGS)
    ffmpeg "${FFMPEG_ARGS[@]}"

    # Wait for wf-recorder to finish and clean up
    wait $WF_RECORDER_PID
    rm "$PIPE_NAME"
elif [ "$SESSION_TYPE" = "x11" ]; then
    ffmpeg "${FFMPEG_ARGS[@]}"
fi

echo
echo "========================================"
echo "Recording stopped."
echo "File saved to: $FILENAME"
echo "========================================"

exit 0
