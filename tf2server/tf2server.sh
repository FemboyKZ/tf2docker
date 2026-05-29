#!/bin/bash

set -ueEo pipefail

mkdir -p "/tmp/tf2home/.steam/sdk64" "/tmp/tf2home/.steam/sdk32"
cp "/watchdog/steamcmd/linux64/steamclient.so" "/tmp/tf2home/.steam/sdk64/"
cp "/watchdog/steamcmd/linux32/steamclient.so" "/tmp/tf2home/.steam/sdk32/"

server_dir="/tmp/tf2server"
mkdir -p "$server_dir"

for (( first=1;; first=0 )); do
    [ $first -eq 0 ] && sleep 10

    # Wait for watchdog to provide latest version
    [ -f "/watchdog/tf2/latest.txt" ] || continue
    build_ver="$(cat /watchdog/tf2/latest.txt)"
    build_dir="/watchdog/tf2/builds/$build_ver"
    [ -d "$build_dir" ] || continue

    rm -rf "$server_dir"/*
    LD_LIBRARY_PATH="$server_dir:$server_dir/bin" HOME="/tmp/tf2home" root="" build_ver="$build_ver" build_dir="$build_dir" server_dir="$server_dir" /bin/bash /user/run.sh
done
