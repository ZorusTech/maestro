#!/usr/bin/env bash

# NOTE: This is a slightly modified version of the original shpotify script
# https://github.com/hnarayanan/shpotify
# The only modification is to disable colors, which was done via find/replace of cecho with echo
# If this issue gets fixed, we should use the original
# https://github.com/hnarayanan/shpotify/issues/96

# Copyright (c) 2012--2018 Harish Narayanan <mail@harishnarayanan.org>
#
# Contains numerous helpful contributions from Jorge Colindres, Thomas
# Pritchard, iLan Epstein, Gabriele Bonetti, Sean Heller, Eric Martin
# and Peter Fonseca.

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

USER_CONFIG_DEFAULTS="CLIENT_ID=\"\"\nCLIENT_SECRET=\"\"";
USER_CONFIG_FILE="${HOME}/.shpotify.cfg";
if ! [[ -f "${USER_CONFIG_FILE}" ]]; then
    touch "${USER_CONFIG_FILE}";
    echo -e "${USER_CONFIG_DEFAULTS}" > "${USER_CONFIG_FILE}";
fi
source "${USER_CONFIG_FILE}";

showAPIHelp() {
    echo;
    echo "Connecting to Spotify's API:";
    echo;
    echo "  This command line application needs to connect to Spotify's API in order to";
    echo "  find music by name. It is very likely you want this feature!";
    echo;
    echo "  To get this to work, you need to sign up (or in) and create an 'Application' at:";
    echo "  https://developer.spotify.com/my-applications/#!/applications/create";
    echo;
    echo "  Once you've created an application, find the 'Client ID' and 'Client Secret'";
    echo "  values, and enter them into your shpotify config file at '${USER_CONFIG_FILE}'";
    echo;
    echo "  Be sure to quote your values and don't add any extra spaces!";
    echo "  When done, it should look like this (but with your own values):";
    echo '  CLIENT_ID="abc01de2fghijk345lmnop"';
    echo '  CLIENT_SECRET="qr6stu789vwxyz"';
}

showHelp () {
    echo "Usage:";
    echo;
    echo "  `basename $0` <command>";
    echo;
    echo "Commands:";
    echo;
    echo "  play                         # Resumes playback where Spotify last left off.";
    echo "  play <song name>             # Finds a song by name and plays it.";
    echo "  play album <album name>      # Finds an album by name and plays it.";
    echo "  play artist <artist name>    # Finds an artist by name and plays it.";
    echo "  play list <playlist name>    # Finds a playlist by name and plays it.";
    echo "  play uri <uri>               # Play songs from specific uri.";
    echo;
    echo "  next                         # Skips to the next song in a playlist.";
    echo "  prev                         # Returns to the previous song in a playlist.";
    echo "  replay                       # Replays the current track from the begining.";
    echo "  pos <time>                   # Jumps to a time (in secs) in the current song.";
    echo "  pause                        # Pauses (or resumes) Spotify playback.";
    echo "  stop                         # Stops playback.";
    echo "  quit                         # Stops playback and quits Spotify.";
    echo;
    echo "  vol up                       # Increases the volume by 10%.";
    echo "  vol down                     # Decreases the volume by 10%.";
    echo "  vol <amount>                 # Sets the volume to an amount between 0 and 100.";
    echo "  vol [show]                   # Shows the current Spotify volume.";
    echo;
    echo "  status                       # Shows the current player status.";
    echo;
    echo "  share                        # Displays the current song's Spotify URL and URI."
    echo "  share url                    # Displays the current song's Spotify URL and copies it to the clipboard."
    echo "  share uri                    # Displays the current song's Spotify URI and copies it to the clipboard."
    echo;
    echo "  toggle shuffle               # Toggles shuffle playback mode.";
    echo "  toggle repeat                # Toggles repeat playback mode.";
    showAPIHelp
}

cecho(){
    bold=$(tput bold);
    green=$(tput setaf 2);
    reset=$(tput sgr0);
    echo $bold$green"$1"$reset;
}

showStatus () {
    state=`osascript -e 'tell application "Spotify" to player state as string'`;
    echo "Spotify is currently $state.";
    artist=`osascript -e 'tell application "Spotify" to artist of current track as string'`;
    album=`osascript -e 'tell application "Spotify" to album of current track as string'`;
    track=`osascript -e 'tell application "Spotify" to name of current track as string'`;
    duration=`osascript -e 'tell application "Spotify"
            set durSec to (duration of current track / 1000) as text
            set tM to (round (durSec / 60) rounding down) as text
            if length of ((durSec mod 60 div 1) as text) is greater than 1 then
                set tS to (durSec mod 60 div 1) as text
            else
                set tS to ("0" & (durSec mod 60 div 1)) as text
            end if
            set myTime to tM as text & ":" & tS as text
            end tell
            return myTime'`;
    position=`osascript -e 'tell application "Spotify"
            set pos to player position
            set nM to (round (pos / 60) rounding down) as text
            if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then
                set nS to (round (pos mod 60) rounding down) as text
            else
                set nS to ("0" & (round (pos mod 60) rounding down)) as text
            end if
            set nowAt to nM as text & ":" & nS as text
            end tell
            return nowAt'`;

    echo -e $reset"Artist: $artist\nAlbum: $album\nTrack: $track \nPosition: $position / $duration";
}

if [ $# = 0 ]; then
    showHelp;
else
    if [ $(osascript -e 'application "Spotify" is running') = "false" ]; then
        osascript -e 'tell application "Spotify" to activate'
        sleep 2
    fi
fi
while [ $# -gt 0 ]; do
    arg=$1;

    case $arg in
        "play"    )
            if [ $# != 1 ]; then
                # There are additional arguments, so find out how many
                array=( $@ );
                len=${#array[@]};
                SPOTIFY_SEARCH_API="https://api.spotify.com/v1/search";
                SPOTIFY_TOKEN_URI="https://accounts.spotify.com/api/token";
                if [ -z "${CLIENT_ID}" ]; then
                    echo "Invalid Client ID, please update ${USER_CONFIG_FILE}";
                    showAPIHelp;
                    exit 1;
                fi
                if [ -z "${CLIENT_SECRET}" ]; then
                    echo "Invalid Client Secret, please update ${USER_CONFIG_FILE}";
                    showAPIHelp;
                    exit 1;
                fi
                SHPOTIFY_CREDENTIALS=$(printf "${CLIENT_ID}:${CLIENT_SECRET}" | base64 | tr -d "\n");
                SPOTIFY_PLAY_URI="";

                getAccessToken() {
                    echo "Connecting to Spotify's API";

                    SPOTIFY_TOKEN_RESPONSE_DATA=$( \
                        curl "${SPOTIFY_TOKEN_URI}" \
                            --silent \
                            -X "POST" \
                            -H "Authorization: Basic ${SHPOTIFY_CREDENTIALS}" \
                            -d "grant_type=client_credentials" \
                    )
                    if ! [[ "${SPOTIFY_TOKEN_RESPONSE_DATA}" =~ "access_token" ]]; then
                        echo "Autorization failed, please check ${USER_CONFG_FILE}"
                        echo "${SPOTIFY_TOKEN_RESPONSE_DATA}"
                        showAPIHelp
                        exit 1
                    fi
                    SPOTIFY_ACCESS_TOKEN=$( \
                        printf "${SPOTIFY_TOKEN_RESPONSE_DATA}" \
                        | grep -E -o '"access_token":".*",' \
                        | sed 's/"access_token"://g' \
                        | sed 's/"//g' \
                        | sed 's/,.*//g' \
                    )
                }

                searchAndPlay() {
                    type="$1"
                    Q="$2"

                    getAccessToken;

                    echo "Searching ${type}s for: $Q";

                    SPOTIFY_PLAY_URI=$( \
                        curl -s -G $SPOTIFY_SEARCH_API \
                            -H "Authorization: Bearer ${SPOTIFY_ACCESS_TOKEN}" \
                            -H "Accept: application/json" \
                            --data-urlencode "q=$Q" \
                            -d "type=$type&limit=1&offset=0" \
                        | grep -E -o "spotify:$type:[a-zA-Z0-9]+" -m 1
                    )
                    echo "play uri: ${SPOTIFY_PLAY_URI}"
                }

                case $2 in
                    "list"  )
                        _args=${array[@]:2:$len};
                        Q=$_args;

                        getAccessToken;

                        echo "Searching playlists for: $Q";

                        results=$( \
                            curl -s -G $SPOTIFY_SEARCH_API --data-urlencode "q=$Q" -d "type=playlist&limit=10&offset=0" -H "Accept: application/json" -H "Authorization: Bearer ${SPOTIFY_ACCESS_TOKEN}" \
                            | grep -E -o "spotify:user:[a-zA-Z0-9_]+:playlist:[a-zA-Z0-9]+" -m 10 \
                        )

                        count=$( \
                            echo "$results" | grep -c "spotify:user" \
                        )

                        if [ "$count" -gt 0 ]; then
                            random=$(( $RANDOM % $count));

                            SPOTIFY_PLAY_URI=$( \
                                echo "$results" | awk -v random="$random" '/spotify:user:[a-zA-Z0-9]+:playlist:[a-zA-Z0-9]+/{i++}i==random{print; exit}' \
                            )
                        fi;;

                    "album" | "artist" | "track"    )
                        _args=${array[@]:2:$len};
                        searchAndPlay $2 "$_args";;

                    "uri"  )
                        SPOTIFY_PLAY_URI=${array[@]:2:$len};;

                    *   )
                        _args=${array[@]:1:$len};
                        searchAndPlay track "$_args";;
                esac

                if [ "$SPOTIFY_PLAY_URI" != "" ]; then
                    if [ "$2" = "uri" ]; then
                        echo "Playing Spotify URI: $SPOTIFY_PLAY_URI";
                    else
                        echo "Playing ($Q Search) -> Spotify URI: $SPOTIFY_PLAY_URI";
                    fi

                    osascript -e "tell application \"Spotify\" to play track \"$SPOTIFY_PLAY_URI\"";

                else
                    echo "No results when searching for $Q";
                fi

            else

                # play is the only param
                echo "Playing Spotify.";
                osascript -e 'tell application "Spotify" to play';
            fi
            break ;;

        "pause"    )
            state=`osascript -e 'tell application "Spotify" to player state as string'`;
            if [ $state = "playing" ]; then
              echo "Pausing Spotify.";
            else
              echo "Playing Spotify.";
            fi

            osascript -e 'tell application "Spotify" to playpause';
            break ;;

        "stop"    )
            state=`osascript -e 'tell application "Spotify" to player state as string'`;
            if [ $state = "playing" ]; then
              echo "Pausing Spotify.";
              osascript -e 'tell application "Spotify" to playpause';
            else
              echo "Spotify is already stopped."
            fi

            break ;;

        "quit"    ) echo "Quitting Spotify.";
            osascript -e 'tell application "Spotify" to quit';
            exit 1 ;;

        "next"    ) echo "Going to next track." ;
            osascript -e 'tell application "Spotify" to next track';
            showStatus;
            break ;;

        "prev"    ) echo "Going to previous track.";
            osascript -e '
            tell application "Spotify"
                set player position to 0
                previous track
            end tell';
            showStatus;
            break ;;

        "replay"  ) echo "Replaying current track.";
            osascript -e 'tell application "Spotify" to set player position to 0'
            break ;;

        "vol"    )
            vol=`osascript -e 'tell application "Spotify" to sound volume as integer'`;
            if [[ $2 = "" || $2 = "show" ]]; then
                echo "Current Spotify volume level is $vol.";
                break ;
            elif [ "$2" = "up" ]; then
                if [ $vol -le 90 ]; then
                    newvol=$(( vol+10 ));
                    echo "Increasing Spotify volume to $newvol.";
                else
                    newvol=100;
                    echo "Spotify volume level is at max.";
                fi
            elif [ "$2" = "down" ]; then
                if [ $vol -ge 10 ]; then
                    newvol=$(( vol-10 ));
                    echo "Reducing Spotify volume to $newvol.";
                else
                    newvol=0;
                    echo "Spotify volume level is at min.";
                fi
            elif [[ $2 =~ ^[0-9]+$ ]] && [[ $2 -ge 0 && $2 -le 100 ]]; then
                newvol=$2;
                echo "Setting Spotify volume level to $newvol";
            else
                echo "Improper use of 'vol' command"
                echo "The 'vol' command should be used as follows:"
                echo "  vol up                       # Increases the volume by 10%.";
                echo "  vol down                     # Decreases the volume by 10%.";
                echo "  vol [amount]                 # Sets the volume to an amount between 0 and 100.";
                echo "  vol                          # Shows the current Spotify volume.";
                break
            fi

            osascript -e "tell application \"Spotify\" to set sound volume to $newvol";
            break ;;

        "toggle"  )
            if [ "$2" = "shuffle" ]; then
                osascript -e 'tell application "Spotify" to set shuffling to not shuffling';
                curr=`osascript -e 'tell application "Spotify" to shuffling'`;
                echo "Spotify shuffling set to $curr";
            elif [ "$2" = "repeat" ]; then
                osascript -e 'tell application "Spotify" to set repeating to not repeating';
                curr=`osascript -e 'tell application "Spotify" to repeating'`;
                echo "Spotify repeating set to $curr";
            fi
            break ;;

        "status" )
            showStatus;
            break ;;

        "info" )
            info=`osascript -e 'tell application "Spotify"
                set durSec to (duration of current track / 1000)
                set tM to (round (durSec / 60) rounding down) as text
                if length of ((durSec mod 60 div 1) as text) is greater than 1 then
                    set tS to (durSec mod 60 div 1) as text
                else
                    set tS to ("0" & (durSec mod 60 div 1)) as text
                end if
                set myTime to tM as text & "min " & tS as text & "s"
                set pos to player position
                set nM to (round (pos / 60) rounding down) as text
                if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then
                    set nS to (round (pos mod 60) rounding down) as text
                else
                    set nS to ("0" & (round (pos mod 60) rounding down)) as text
                end if
                set nowAt to nM as text & "min " & nS as text & "s"
                set info to "" & "\nArtist:         " & artist of current track
                set info to info & "\nTrack:          " & name of current track
                set info to info & "\nAlbum Artist:   " & album artist of current track
                set info to info & "\nAlbum:          " & album of current track
                set info to info & "\nSeconds:        " & durSec
                set info to info & "\nSeconds played: " & pos
                set info to info & "\nDuration:       " & mytime
                set info to info & "\nNow at:         " & nowAt
                set info to info & "\nPlayed Count:   " & played count of current track
                set info to info & "\nTrack Number:   " & track number of current track
                set info to info & "\nPopularity:     " & popularity of current track
                set info to info & "\nId:             " & id of current track
                set info to info & "\nSpotify URL:    " & spotify url of current track
                set info to info & "\nArtwork:        " & artwork url of current track
                set info to info & "\nPlayer:         " & player state
                set info to info & "\nVolume:         " & sound volume
                set info to info & "\nShuffle:        " & shuffling
                set info to info & "\nRepeating:      " & repeating
            end tell
            return info'`
            echo "$info";
            break ;;

        "share"     )
            uri=`osascript -e 'tell application "Spotify" to spotify url of current track'`;
            remove='spotify:track:'
            url=${uri#$remove}
            url="https://open.spotify.com/track/$url"

            if [ "$2" = "" ]; then
                echo "Spotify URL: $url"
                echo "Spotify URI: $uri"
                echo "To copy the URL or URI to your clipboard, use:"
                echo "\`spotify share url\` or"
                echo "\`spotify share uri\` respectively."
            elif [ "$2" = "url" ]; then
                echo "Spotify URL: $url";
                echo -n $url | pbcopy
            elif [ "$2" = "uri" ]; then
                echo "Spotify URI: $uri";
                echo -n $uri | pbcopy
            fi
            break;;

        "pos"   )
            echo "Adjusting Spotify play position."
            osascript -e "tell application \"Spotify\" to set player position to $2";
            break;;

        "help" )
            showHelp;
            break ;;

         * )
            showHelp;
            echo "MEH" > /tmp/meh.txt;
            exit 1;
            break ;;
    esac
done
