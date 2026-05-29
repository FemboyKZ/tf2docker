#!/bin/bash

set -ueEo pipefail

fetch_latest_tf2_version() {
    local api_url="https://api.steampowered.com/ISteamApps/UpToDateCheck/v1?version=0&format=json&appid=232250"
    curl -sf $api_url | jq -re ".response.required_version | select(type == \"number\")"
}

update_tf2() {
    # Download tf2 to /watchdog/tf2/install
    HOME="/watchdog/steamcmd" /watchdog/steamcmd/steamcmd.sh +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +@bMetricsEnabled 0 +force_install_dir "/watchdog/tf2/install" +login anonymous +app_update 232250 validate +quit 1>&2

    # Check which version we just installed
    local installed_version="$(grep PatchVersion= "/watchdog/tf2/install/game/tf/steam.inf" | tr -cd "0-9")"

    # Return if we already have this version
    [ ! -d "/watchdog/tf2/builds/$installed_version" ]

    # Hard symlink the files from /watchdog/tf2/install to /watchdog/.tmp, then rename /watchdog/.tmp to /watchdog/tf2/builds/????? so it's atomic.
    # Must use a tmp directory inside of the /watchdog because symlinks don't work across filesystems.
    cp -rl "/watchdog/tf2/install" "/watchdog/.tmp"
    mv "/watchdog/.tmp" "/watchdog/tf2/builds/$installed_version"

    # Store the version in latest.txt so servers can detect an update
    rm "/tmp/latest.txt"
    echo "$installed_version" > "/tmp/latest.txt"
    mv "/tmp/latest.txt" "/watchdog/tf2/latest.txt"
}

# Download SteamCMD
if [ ! -d "/watchdog/steamcmd" ]; then
    mkdir -p "/tmp/steamcmd"
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C "/tmp/steamcmd"
    mv "/tmp/steamcmd" "/watchdog/steamcmd"
fi

mkdir -p "/watchdog/tf2/builds"

for (( first=1;; first=0 )); do
    [ $first -eq 0 ] && sleep 10

    # The temporary directory might exist if update_tf2 fails
    rm -rf "/watchdog/.tmp"

    latest_version="$(fetch_latest_tf2_version)" || continue

    # Remove outdated tf2 builds that are not being used by any server
    find "/watchdog/tf2/builds" -mindepth 1 -maxdepth 1 -type d ! -name "$latest_version" -exec flock -nx "{}/.lockfile" --command "rm -rf \"{}\"" \; || true

    # Update tf2 if we don't have the latest version
    if [ ! -d "/watchdog/tf2/builds/$latest_version" ]; then
        update_tf2 || true
    fi
done
