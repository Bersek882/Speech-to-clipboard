### Speech to Clipboard

A simple Bash script to record audio from your microphone, send it to a speech-to-text service, and copy the resulting text to your clipboard.

The script uses a toggle mechanism:
*   **First run:** Starts recording.
*   **Second run:** Stops recording, transcribes the audio, and copies the text to the clipboard.

It also features desktop notifications for status updates and a configurable recording timeout.

#### Features

*   Record audio using `arecord`.
*   Transcribe audio using speech-to-text services (currently configured for ElevenLabs API).
*   Copy transcription to clipboard (uses `wl-copy` for Wayland by default).
*   Desktop notifications for recording, transcribing, success, and errors.
*   Automatic recording timeout to prevent indefinite recording.
*   Basic error handling and logging for `arecord`.
*   Option to remove content in parentheses at the start/end of the transcription.

#### Compatibility

##### Supported Operating Systems

This script is designed to work natively without modifications on:

**Linux-Distributions with Wayland Compositor:**
* Ubuntu 22.04 LTS and newer (with Wayland enabled)
* Fedora 34 and newer (Wayland is default)
* Arch Linux (with Wayland session)
* Pop!_OS 22.04 and newer (with Wayland enabled)
* openSUSE Tumbleweed (with Wayland)
* Debian 11 "Bullseye" and newer (with Wayland)
* Manjaro (with Wayland session) 
* Ubuntu-derivatives like Kubuntu, Xubuntu (if configured with Wayland)

##### Compatible with Modifications

The script can be adapted to work on the following systems with minor modifications:

**Linux with X11:**
Replace `wl-copy` with `xclip -selection clipboard` or `xsel --clipboard --input` in the script and install the appropriate package (`xclip` or `xsel`).

**macOS:**
Requires replacing `arecord` with `rec` (from SoX), `wl-copy` with `pbcopy`, and `notify-send` with an alternative notification tool.

**Windows (WSL):**
Not directly supported due to audio input limitations in WSL. Would require significant adaptations and possibly additional software to bridge audio capture from Windows to WSL.

##### Not Compatible
* BSD variants without significant modifications

#### Configuration

1.  **API Key (Mandatory):**
    You **must** configure your speech-to-text API key. The script currently uses ElevenLabs, but the code can be adapted for other services.
    *   Set the API key directly in the script:
        ```bash
        ELEVENLABS_API_KEY="YOUR_API_KEY" # <-- PASTE YOUR API KEY HERE!
        ```
        Replace `"YOUR_API_KEY"` with your actual key.

2.  **Speech-to-Text Service (Optional):**
    The script is currently configured to use ElevenLabs API, but you can modify it to work with other services like:
    * OpenAI Whisper API
    * Google Cloud Speech-to-Text
    * Microsoft Azure Speech Services
    * Amazon Transcribe
    * Local Whisper models (with appropriate modifications)
    
    When switching to another service, you'll need to modify the API endpoint, request format, and response parsing in the script accordingly.
    
3.  **ElevenLabs Model ID (Optional if using ElevenLabs):**
    The script uses `ELEVENLABS_MODEL_ID="scribe_v1"` by default. You can change this to other available speech-to-text models from ElevenLabs if needed.
    ```bash
    ELEVENLABS_MODEL_ID="your_chosen_model_id"
    ```

#### Prerequisites

Before using this script, ensure you have the following dependencies installed:

*   **`bash`**: The script is written in Bash.
*   **`curl`**: Used to make API requests.
    *   Install on Debian/Ubuntu: `sudo apt install curl`
*   **`jq`**: A lightweight and flexible command-line JSON processor. Used to parse the API response.
    *   Install on Debian/Ubuntu: `sudo apt install jq`
*   **`arecord`**: Part of `alsa-utils`, used for audio recording.
    *   Install on Debian/Ubuntu: `sudo apt install alsa-utils`
*   **`notify-send`**: Used for desktop notifications. Typically part of `libnotify-bin`.
    *   Install on Debian/Ubuntu: `sudo apt install libnotify-bin`
*   **`wl-copy`**: Part of `wl-clipboard`, used to copy text to the clipboard on Wayland.
    *   Install on Debian/Ubuntu: `sudo apt install wl-clipboard`
    *   **Note for X11 users:** This script uses `wl-copy`. If you are using an X11-based desktop environment, you will need to replace `wl-copy` with `xclip -selection clipboard` or `xsel --clipboard --input` in the script, and install the respective tool (`xclip` or `xsel`).

*   **An API Key for your chosen speech-to-text service**: You need an account with the service and an API key to use their speech-to-text service.

#### Installation

1.  **Download the script:**
    Save the script content as `Speech_to_Clipboard.sh` in your desired location (e.g., `~/.local/bin/`).

2.  **Make it executable:**
    Open your terminal and navigate to the directory where you saved the script, then run:
    ```bash
    chmod +x Speech_to_Clipboard.sh
    ```

#### Usage

1.  **Run the script:**
    Execute the script from your terminal:
    ```bash
    /path/to/Speech_to_Clipboard.sh
    ```
    Or, if it's in your `PATH` (e.g., `~/.local/bin/` which is often in `PATH` by default):
    ```bash
    Speech_to_Clipboard.sh
    ```

2.  **First Execution:**
    *   A notification "Recording..." will appear.
    *   The script starts recording audio from your default microphone.

3.  **Second Execution:**
    *   A notification "Transcribing..." will appear.
    *   The recording stops.
    *   The recorded audio is sent to the speech-to-text service.
    *   If successful, the transcribed text is copied to your clipboard, and a "Ready (Copied to Clipboard)" notification appears.
    *   If an error occurs (e.g., API error, no speech detected), an error notification will be shown.

4.  **Recording Timeout:**
    If the recording is not manually stopped by running the script a second time, it will automatically stop after the duration specified by `RECORDING_TIMEOUT`. A notification "Recording stopped (Timeout). Audio discarded." will appear, and the audio will not be processed.

#### Binding to a Keyboard Shortcut (Recommended)

For convenient use, it's highly recommended to bind this script to a keyboard shortcut in your desktop environment (e.g., GNOME, KDE, XFCE, i3wm).

For example, in GNOME:
*   Go to Settings -> Keyboard -> Keyboard Shortcuts (or View and Customize Shortcuts).
*   Scroll down to "Custom Shortcuts" and click the "+" button.
*   Name: `Speech to Clipboard`
*   Command: `/path/to/your/Speech_to_Clipboard.sh`
*   Set your desired shortcut.

#### Troubleshooting

*   **"API Key not configured"**: Ensure your API key is correctly set in the script.
*   **"wl-copy not found"**: Install the appropriate clipboard utility (`wl-clipboard` for Wayland, `xclip` or `xsel` for X11) and adjust the script if necessary.
*   **"arecord not found" / "curl not found" / "jq not found"**: Install the missing dependencies using your system's package manager.
*   **Recording fails to start / "Error: Recording failed to start. Check audio device."**:
    *   Ensure your microphone is properly connected and configured in your system's audio settings.
    *   Check the `arecord` error log specified by `ARECORD_LOG_FILE` for more details. You might need to specify a different audio device for `arecord` by modifying `ARECORD_PARAMS` (e.g., `arecord -D hw:1,0 ...`). Use `arecord -l` to list available recording devices.
*   **Transcription errors / API errors**:
    *   Check your internet connection.
    *   Verify your API key is correct and your account has credits/access.
    *   The API service might be temporarily unavailable.
    *   The error notification should provide more details.
*   **"No speech detected"**: The API could not detect any speech in the recorded audio. Try speaking louder or closer to the microphone.
*   **"Unexpected API Response"**: The script received a response that it couldn't parse correctly. This might indicate a change in the API or an unexpected error.

## License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

## Author

[Bersek882](https://github.com/Bersek882)