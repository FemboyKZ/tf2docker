# FKZ Docker

Deduplicated Team Fortress 2 server hosting in Docker.

TF2 fork of csgo fork of cs2 fork, wack so I recommend not using this.

## Watchdog

The watchdog image keeps Counter-Strike Global Offensive up to date.

#### Volumes:

- `/watchdog` - The directory where Steam and Counter-Strike Global Offensive will be installed to.

## Server

The server image runs an instance of a Counter-Strike Global Offensive server. You can run as many as your hardware can handle.

#### Volumes:

- `/watchdog` - Has to be the same as the one passed to the watchdog.
- `/user/run.sh` - The script that sets up and runs the server.

#### Volumes convention (not used by tf2docker itself, but it's the recommended naming convention):

- `/layers` - Plugin binaries that you copy-paste from `run.sh` (SourceMod, GOKZ, etc.).
- `/mounts` - Files and directories that you symlink from `run.sh` (mapcycle.txt, log directories, etc.).

## run.&#8203;sh

It's recommended you edit [the example in this README](#runsh-1).

#### Environment variables:

- `$build_ver` - The version number of Team Fortress 2 that the server should use.
- `$build_dir` - The directory where that version of Team Fortress 2 is installed.
- `$server_dir` - The directory where you should build the server.
- Everything passed to Docker.

## Example

#### docker-compose.yml

```yml
services:
  tf2watchdog:
    image: tf2watchdog
    container_name: tf2watchdog
    restart: unless-stopped
    user: 1000:1000
    volumes:
      - ./watchdog:/watchdog
  tf2server1:
    image: tf2server
    container_name: tf2server1
    restart: unless-stopped
    user: 1000:1000
    ports:
      - "27015:27015/udp"
      - "27015:27015/tcp"
    environment:
      - GSLT=
    volumes:
      - ./watchdog:/watchdog
      - ./layers:/layers
      - ./mounts:/mounts
      - ./user:/user:ro
  tf2server2:
    image: tf2server
    container_name: tf2server2
    restart: unless-stopped
    user: 1000:1000
    ports:
      - "27020:27015/udp"
      - "27020:27015/tcp"
    environment:
      - GSLT=
    volumes:
      - ./watchdog:/watchdog
      - ./layers:/layers
      - ./mounts:/mounts
      - ./user:/user:ro
```

#### run.&#8203;sh

```bash
#!/bin/bash

set -ueEo pipefail

echo "Build version: $build_ver"
echo "Build directory: $build_dir"
echo "GSLT: $GSLT"

# Symlink all the server files.
cp -rs "$build_dir"/* "$server_dir"

# Mount maps folder.
ln -s "/mounts/maps" "$server_dir/maps"

# Run the server
"$server_dir/srcds_linux" -game tf2 -strictportbind -port "$PORT" -nobreakpad -noautoupdate +sv_setsteamaccount "$GSLT" +map ???
```
