#! /bin/bash

# Name of the RC file.
RC_FILE=${HOME}/.startjackrc
CALF_CONFIG=/mnt/data/Podcasts/calf_config.xml

function assert_command_exist()
{
    type ${1} 1>/dev/null 2>&1
    if [[ "${?}" -eq 1 ]]; then
        echo "ERROR! command \"${1}\" is not available."
        exit 1
    fi
}

# Assert that the commands we will need are in the command path.
assert_command_exist pactl
assert_command_exist pacmd
assert_command_exist head
assert_command_exist tail
assert_command_exist screen
assert_command_exist jackd
assert_command_exist calfjackhost
assert_command_exist jack_disconnect
assert_command_exist jack_connect

# If the RC file exists, read the capture and playback devices.
if [[ -f ${RC_FILE} ]]; then
    CAPTURE_DEVICE=$(head -n 1 ${RC_FILE})
    PLAYBACK_DEVICE=$(tail -n 1 ${RC_FILE})
fi

# Analyse command line to set capture and playback devices.
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -c | --capture)
            CAPTURE_DEVICE="${2}"
            shift
            shift
            ;;
        -p | --playback)
            PLAYBACK_DEVICE="${2}"
            shift
            shift
            ;;
        *)
            echo "ERROR! \"${1}\" is not a valid parameter."
            exit 1
            ;;
    esac
done

# Check if both the capture and the playback devices were specified.
if [[ ! -v CAPTURE_DEVICE || ! -v PLAYBACK_DEVICE ]]; then
    [[ ! -v CAPTURE_DEVICE ]] && echo "ERROR! No capture device specified"
    [[ ! -v PLAYBACK_DEVICE ]] && echo "ERROR! No playback device specidied."
    exit 1
fi

# Create an empty RC file if it does exist already
[[ ! -f ${RC_FILE} ]] && touch ${RC_FILE}

# If the RC file exist, write selected capture and playback devices.
[[ -f ${RC_FILE} ]] && echo ${CAPTURE_DEVICE} > ${RC_FILE} && echo ${PLAYBACK_DEVICE} >> ${RC_FILE}

# Get the currently active input and output devices
PREVIOUS_INPUT_DEVICE=$(LC_LANG=C pacmd list-sinks | grep ' \* index' | sed 's/[^0-9]*//')
PREVIOUS_OUTPUT_DEVICE=$(LC_LANG=C pacmd list-sources | grep ' \* index' | sed 's/[^0-9]*//')

# Suspend pulse
pacmd suspend 1

# Start jack
screen -d -m -S jack jackd -dalsa -r44100 -p128 -n4 -D -Chw:${CAPTURE_DEVICE} -Phw:${PLAYBACK_DEVICE}

# Give jack a second to load
sleep 1

# Load jack sink and jack source
pactl load-module module-jack-sink
pactl load-module module-jack-source

# Start calfjackhost with my configuration
screen -d -m -S calf calfjackhost --load ${CALF_CONFIG}

# Give it a second to load
sleep 1

# Disconnect pulse source
jack_disconnect system:capture_1 "PulseAudio JACK Source:front-left"
jack_disconnect system:capture_2 "PulseAudio JACK Source:front-right"

# Connect ports
jack_connect system:capture_1 "Calf Studio Gear:gate In #1"
jack_connect "Calf Studio Gear:gate Out #1" "Calf Studio Gear:eq8 In #1"
jack_connect "Calf Studio Gear:eq8 Out #1" "Calf Studio Gear:deesser In #1"
jack_connect "Calf Studio Gear:deesser Out #1" "Calf Studio Gear:monocompressor In #1"
jack_connect "Calf Studio Gear:monocompressor Out #1" "Calf Studio Gear:limiter In #1"
jack_connect "Calf Studio Gear:limiter Out #1" system:playback_1
jack_connect "Calf Studio Gear:limiter Out #1" system:playback_2
jack_connect "Calf Studio Gear:limiter Out #1" "PulseAudio JACK Source:front-left"
jack_connect "Calf Studio Gear:limiter Out #1" "PulseAudio JACK Source:front-right"

# Set jack as active default sink and source 
pactl set-default-source jack_in
pactl set-default-sink jack_out

# Unsuspend jack sink and jack source
pacmd suspend-source jack_in 0
pacmd suspend-sink jack_out 0

# Wait for Calf JACK Host to be killed
screen -r calf

# Set default sink and source back to their original values
pactl set-default-source ${PREVIOUS_OUTPUT_DEVICE}
pactl set-default-sink ${PREVIOUS_INPUT_DEVICE}

# Unload pulse sink and source
pactl unload-module module-jack-source
pactl unload-module module-jack-sink

# Killly active
screen -X -S jack quit

# Resume pulse
pacmd suspend 0
