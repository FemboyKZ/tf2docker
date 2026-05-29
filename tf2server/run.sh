#!/bin/bash

set -ueEo pipefail

# Symlink all the server files.
cp -rs "$build_dir"/* "$server_dir"

# Run the server.
"$server_dir/srcds_linux" -game tf2 -strictportbind -port "$PORT" -nobreakpad -noautoupdate +sv_setsteamaccount "$GSLT" +map ctf_2fort
