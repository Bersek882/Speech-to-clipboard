#!/bin/bash

# --- Configuration ---
# IMPORTANT: Set your ElevenLabs API Key here.
ELEVENLABS_API_KEY="YOUR_ELEVENLABS_API_KEY" # <-- PASTE YOUR API KEY HERE!

# Check if ELEVENLABS_API_KEY has been set
if [ "$ELEVENLABS_API_KEY" = "YOUR_ELEVENLABS_API_KEY" ]; then
    echo "Error: ELEVENLABS_API_KEY is not set in the script."
    # Attempt to send a notification even if the key is missing, for user feedback
    if command -v notify-send &> /dev/null; then
        notify-send -u critical -i "dialog-error-symbolic" "Speech to Clipboard" "API Key not configured in script!"
    fi
    exit 1
fi

# ElevenLabs Model ID for Speech-to-Text.
# Valid models include: scribe_v1, scribe_v1_experimental
# Check ElevenLabs documentation for the latest models.
ELEVENLABS_MODEL_ID="scribe_v1"

# Temporary audio file path
TMP_AUDIO_FILE="/tmp/speech_to_clipboard_recording.wav"
# PID file to store the process ID of arecord
PID_FILE="/tmp/speech_to_clipboard_recording_pid.txt"
# Log file for arecord errors
ARECORD_LOG_FILE="/tmp/speech_to_clipboard_arecord_error.log"
# PID file for the timeout process
TIMER_PID_FILE="/tmp/speech_to_clipboard_recording_timer_pid.txt"
# Recording timeout in seconds (e.g., 120 for 2 minutes)
RECORDING_TIMEOUT=120

# arecord parameters: -q (quiet), -f (format), -r (rate), -c (channels)
# S16_LE is a common format (signed 16-bit little-endian PCM)
# 16000 Hz is a common sample rate for speech
ARECORD_PARAMS="-q -f S16_LE -r 16000 -c 1"

# Icons for notifications (uses standard freedesktop.org icon names)
ICON_RECORDING="audio-input-microphone-symbolic"
ICON_TRANSCRIBING="preferences-system-time-symbolic" # Or "system-search-symbolic"
ICON_READY="edit-copy-symbolic"
ICON_ERROR="dialog-error-symbolic"
ICON_TIMEOUT="dialog-warning-symbolic"
# --- End Configuration ---

# --- Function to clean up all temporary files ---
cleanup() {
    # Remove PID files, temporary audio file, and log file
    rm -f "$PID_FILE" "$TIMER_PID_FILE" "$TMP_AUDIO_FILE" "$ARECORD_LOG_FILE"
}

# --- Dependency Checks ---
# Check for notify-send for desktop notifications
if ! command -v notify-send &> /dev/null; then
    echo "Error: notify-send not found. Please install libnotify-bin or a similar package."
    exit 1
fi
# Check for wl-copy (Wayland clipboard utility)
# For X11, users might need to replace this with xclip or xsel
if ! command -v wl-copy &> /dev/null; then
    echo "Error: wl-copy not found (for Wayland). Please install wl-clipboard."
    echo "If you are using X11, you might need to install xclip or xsel and modify the script."
    notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "wl-copy not found. Please install wl-clipboard."
    exit 1
fi
# Check for arecord (audio recording utility)
if ! command -v arecord &> /dev/null; then
    echo "Error: arecord not found. Please install alsa-utils."
    notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "arecord not found. Please install alsa-utils."
    exit 1
fi
# Check for curl (data transfer utility)
if ! command -v curl &> /dev/null; then
    echo "Error: curl not found. Please install curl."
    notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "curl not found. Please install curl."
    exit 1
fi
# Check for jq (JSON processor)
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Please install jq."
    notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "jq not found. Please install jq."
    exit 1
fi
# --- End Dependency Checks ---

# --- Main Logic ---
# Check if the PID_FILE exists, which means a recording is in progress
if [ -f "$PID_FILE" ]; then
    # --- Stop Recording and Transcribe ---
    ARECORD_PID=$(cat "$PID_FILE") # Read the PID of the arecord process
    echo "Stopping recording (PID: $ARECORD_PID)..."

    # Stop the background timer process if it exists
    if [ -f "$TIMER_PID_FILE" ]; then
        TIMER_PID=$(cat "$TIMER_PID_FILE")
        echo "Stopping timeout timer (PID: $TIMER_PID)..."
        kill "$TIMER_PID" &> /dev/null # Suppress output from kill
        rm -f "$TIMER_PID_FILE" # Remove the timer PID file
    fi

    notify-send -u normal -t 3000 -i $ICON_TRANSCRIBING "Speech to Clipboard" "Transcribing..."

    # Attempt to kill the arecord process
    if kill "$ARECORD_PID" &> /dev/null; then
        sleep 0.3 # Give arecord a moment to finish writing the audio file
        rm -f "$PID_FILE" # Remove arecord PID file as recording is stopped
        echo "Recording stopped. PID file removed."

        # Check if the temporary audio file exists and is not empty
        if [ -s "$TMP_AUDIO_FILE" ]; then
            echo "Transcribing $TMP_AUDIO_FILE via ElevenLabs API..."

            # Call the ElevenLabs API using curl
            # -s: silent mode (no progress meter)
            # -f: fail silently on HTTP errors (curl will exit with an error code)
            # -X POST: specify POST request method
            # -H: set headers (Accept and xi-api-key)
            # -F: submit multipart/form-data (file and model_id)
            API_RESPONSE=$(curl -s -f -X POST \
                -H "Accept: application/json" \
                -H "xi-api-key: $ELEVENLABS_API_KEY" \
                -F "file=@$TMP_AUDIO_FILE" \
                -F "model_id=$ELEVENLABS_MODEL_ID" \
                "https://api.elevenlabs.io/v1/speech-to-text")
            CURL_EXIT_CODE=$? # Get the exit code of the curl command

            TRANSCRIPTION_TEXT="" # Initialize transcription text variable

            if [ $CURL_EXIT_CODE -ne 0 ]; then
                # curl command failed (e.g., network error, or HTTP error because -f was used)
                echo "Error: curl command failed with exit code $CURL_EXIT_CODE."
                # Try to parse error detail from API_RESPONSE if it contains any JSON
                ERROR_DETAIL=$(echo "$API_RESPONSE" | jq -r '.detail.message // .detail // "Unknown curl/network error"')
                notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "Transcription Failed: $ERROR_DETAIL (curl code: $CURL_EXIT_CODE)"
            else
                # curl succeeded, now check the content of the JSON response from the API
                # Check if the API response contains a 'detail' field, indicating an API-specific error
                API_ERROR_MSG=$(echo "$API_RESPONSE" | jq -r 'if .detail then (.detail.message // .detail) else null end')

                if [ "$API_ERROR_MSG" != "null" ] && [ -n "$API_ERROR_MSG" ]; then
                    # The API returned a specific error message
                    echo "Error: ElevenLabs API returned an error: $API_ERROR_MSG"
                    notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "API Error: $API_ERROR_MSG"
                else
                    # Try to extract the transcription text from the '.text' field
                    # jq -e sets exit code 1 if .text is null or not found, 0 otherwise
                    TRANSCRIPTION_TEXT=$(echo "$API_RESPONSE" | jq -e -r '.text // empty')
                    JQ_EXIT_CODE=$?

                    if [ $JQ_EXIT_CODE -ne 0 ] || [ -z "$TRANSCRIPTION_TEXT" ]; then
                        # jq failed to extract text (e.g., unexpected JSON structure) or the text field was empty/null
                        echo "Transcription successful but no speech detected or unexpected API response."
                        if [ $JQ_EXIT_CODE -ne 0 ]; then
                            # This means the JSON structure was not as expected
                            echo "Unexpected API response format: $API_RESPONSE"
                            notify-send -u normal -t 3000 -i $ICON_ERROR "Speech to Clipboard" "Unexpected API Response"
                        else
                            # This means .text was null or empty, likely no speech detected
                            notify-send -u normal -t 3000 -i $ICON_ERROR "Speech to Clipboard" "No speech detected"
                        fi
                        TRANSCRIPTION_TEXT="" # Ensure it's empty for safety
                    else
                        # Transcription was successful and text was extracted
                        echo "Raw transcription: [$TRANSCRIPTION_TEXT]"

                        # Post-processing: Remove content within parentheses at the beginning/end and trim whitespace
                        # 1. s/^[[:space:]]*\([^)]*\)// : Removes leading spaces and then (...)
                        # 2. s/\([^)]*\)[[:space:]]*$// : Removes (...) and then trailing spaces
                        # 3. s/^[[:space:]]*// : Trims leading whitespace (again, for robustness)
                        # 4. s/[[:space:]]*$// : Trims trailing whitespace (again, for robustness)
                        TRANSCRIPTION_TEXT=$(echo "$TRANSCRIPTION_TEXT" | sed -E 's/^[[:space:]]*\([^)]*\)//; s/\([^)]*\)[[:space:]]*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
                        echo "Processed transcription: [$TRANSCRIPTION_TEXT]"

                        # Copy the processed text to the clipboard using wl-copy
                        echo "Copying processed text to clipboard:"
                        echo "$TRANSCRIPTION_TEXT" | wl-copy
                        notify-send -u normal -t 5000 -i $ICON_READY "Speech to Clipboard" "Ready (Copied to Clipboard)"
                    fi
                fi
            fi

            echo "Removing temporary audio file: $TMP_AUDIO_FILE"
            rm -f "$TMP_AUDIO_FILE" # Clean up the audio file
        else
            echo "Error: Temporary audio file $TMP_AUDIO_FILE is empty or missing after recording."
            notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "Error: Audio file empty/missing."
            cleanup # Clean up all temp files in case of error
        fi
    else
        echo "Error: Could not find or kill process with PID $ARECORD_PID. Maybe it finished unexpectedly?"
        notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "Error stopping recording process."
        cleanup # Clean up all temp files
    fi
else
    # --- Start Recording ---
    echo "Attempting to start recording using default device..."
    cleanup # Clean up any previous temporary files before starting a new recording

    # Start arecord in the background, redirect stderr to a log file for troubleshooting
    arecord $ARECORD_PARAMS "$TMP_AUDIO_FILE" 2> "$ARECORD_LOG_FILE" &
    ARECORD_PID=$! # Get the PID of the backgrounded arecord process
    echo "Waiting 0.5 second for process $ARECORD_PID to stabilize..."
    sleep 0.5 # Short pause to allow arecord to initialize or fail

    # Check if the arecord process is still running
    if kill -0 $ARECORD_PID &> /dev/null; then # -0 doesn't send a signal, just checks if process exists
        echo "Recording process $ARECORD_PID seems stable."
        echo $ARECORD_PID > "$PID_FILE" # Store the PID in the PID file
        notify-send -u normal -t 4000 -i $ICON_RECORDING "Speech to Clipboard" "Recording..."
        echo "Recording started (PID: $ARECORD_PID). Saving to $TMP_AUDIO_FILE"
        # Remove the error log file if arecord started successfully (no errors written)
        if [ -s "$ARECORD_LOG_FILE" ]; then # Check if log file has size (contains errors)
            echo "Warning: arecord produced some output/errors, check $ARECORD_LOG_FILE"
        else
            rm -f "$ARECORD_LOG_FILE" # Remove empty log file
        fi


        # Start a background timer process to stop recording after RECORDING_TIMEOUT
        echo "Starting timeout timer (${RECORDING_TIMEOUT}s)..."
        (
            sleep "$RECORDING_TIMEOUT"
            # Check if the recording is still supposed to be running (PID_FILE exists)
            if [ -f "$PID_FILE" ]; then
                RECORDING_PID_TO_KILL=$(cat "$PID_FILE")
                echo "Timeout reached ($RECORDING_TIMEOUT s). Stopping recording PID $RECORDING_PID_TO_KILL automatically."
                # Check if the process actually exists before attempting to kill
                if kill -0 "$RECORDING_PID_TO_KILL" &> /dev/null; then
                    kill "$RECORDING_PID_TO_KILL" &> /dev/null # Stop the recording
                fi
                cleanup # Clean up all temp files after timeout kill
                notify-send -u normal -t 5000 -i $ICON_TIMEOUT "Speech to Clipboard" "Recording stopped (Timeout). Audio discarded."
            fi
            # The timer process cleans up its own PID file if recording was stopped manually or timed out
            rm -f "$TIMER_PID_FILE"
        ) &
        TIMER_PID=$! # Get PID of the timer subshell
        echo $TIMER_PID > "$TIMER_PID_FILE" # Store timer PID
        echo "Timeout timer started (PID: $TIMER_PID)."
        # --- End Timer ---

    else
        # arecord process died shortly after start
        echo "Error: Recording process $ARECORD_PID died shortly after start."
        # Display the content of the arecord error log file if it exists and is not empty
        if [ -s "$ARECORD_LOG_FILE" ]; then
            echo "--- arecord error log ($ARECORD_LOG_FILE): ---"
            cat "$ARECORD_LOG_FILE"
            echo "---------------------------------------------"
            notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "Recording failed. Check audio device. Log: $ARECORD_LOG_FILE"
        else
            notify-send -u critical -i $ICON_ERROR "Speech to Clipboard" "Recording failed to start. Check audio device."
        fi
        cleanup # Clean up any files created
        exit 1
    fi
fi
# --- End Main Logic ---

exit 0