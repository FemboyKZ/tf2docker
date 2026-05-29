#!/bin/bash
trap '' SIGINT
set -ueEo pipefail

# initialize variables
databases_cfg=""
actual_gslt=""

# helper functions
append_database() {
    databases_cfg+="\n\"$1\"\n{\ndriver \"$2\"\nhost \"$3\"\nport \"$4\"\ndatabase \"$5\"\nuser \"$6\"\npass \"$7\"\ntimeout \"$8\"\n}\n"
}

install_layer() {
    cp -rf "$root/layers/$1"/* "$server_dir/tf"
}

install_mount() {
    rm -rf "$server_dir/tf/$2"
    ln -s "$root/mounts/$1" "$server_dir/tf/$2"
}

# wrapper for admin mounts
install_mount_admins() {
    install_mount "$1/cfg/admins_simple.ini" "addons/sourcemod/configs/admins_simple.ini"
    install_mount "$1/cfg/admins.cfg" "addons/sourcemod/configs/admins.cfg"
    install_mount "$1/cfg/admin_groups.cfg" "addons/sourcemod/configs/admin_groups.cfg"
    install_mount "$1/cfg/admin_overrides.cfg" "addons/sourcemod/configs/admin_overrides.cfg"
}

# make sure necessary directories exist and copy base game files
mkdir -p "$server_dir/tf/cfg" "$server_dir/tf/maps" "$server_dir/tf/materials" "$server_dir/tf/models" "$server_dir/tf/sound" "$server_dir/tf/addons"
cp -rs "$build_dir"/* "$server_dir"

mkdir -p "mounts/replays" "mounts/maps" "mounts/$ID/sqlite" "mounts/$ID/cfg" "mounts/$ID/logs/sourcemod" "mounts/$ID/logs/tf" "mounts/$ID/logs/GlobalAPI" "mounts/$ID/logs/GlobalAPI-Retrying"
mkdir -p "mounts/fkz-1/sqlite" "mounts/fkz-1/cfg" "mounts/fkz-1/logs/sourcemod" "mounts/fkz-1/logs/tf" "mounts/fkz-1/logs/GlobalAPI" "mounts/fkz-1/logs/GlobalAPI-Retrying"

# create server.cfg
cat <<EOF > "$server_dir/tf/cfg/server.cfg"
    hostname "$HOSTNAME"
    sv_contact "$CONTACT"
    sv_steamgroup "$STEAMGROUP"
    sv_password "$PASSWORD"
    rcon_password "$RCON_PASSWORD"

    host_name_store 1
    host_info_show 1
    host_players_show 2
    sv_lan 0
    sv_region -1
    sv_tags "$TAGS"

    sv_downloadurl "$FASTDL_URL"
    //sv_allowdownload 1
    //sv_allowupload 1
    //sv_workshop_allow_other_maps 1
    sv_pure 0
    sv_pure_kick_clients 0

    sv_hibernate_when_empty 1
    sv_hibernate_ms 20
    sv_hibernate_postgame_delay 20

    sv_minrate 98304
    sv_maxrate 0
    mp_autokick 0

    log on
    sv_log_onefile 0
    sv_logbans 1
    sv_logecho 1
    sv_logfile 1
    sv_logflush 0

    exec banned_user.cfg
    exec banned_ip.cfg
    writeid
    writeip

    exec fkz-print.cfg
    mp_restartgame 1
EOF

# Set webapi authkey
rm -f "$server_dir/tf/webapi_authkey.txt"
echo "$WS_APIKEY" > "$server_dir/tf/webapi_authkey.txt"

# Install MM & SM
install_layer "MetaMod"
install_layer "SourceMod"

# Remove default plugins that are not needed
rm -f "$server_dir/tf/addons/sourcemod/extensions/updater.ext.so"
rm -f "$server_dir/tf/addons/sourcemod/plugins/funvotes.smx"
rm -f "$server_dir/tf/addons/sourcemod/plugins/funcommands.smx"
rm -f "$server_dir/tf/addons/sourcemod/plugins/playercommands.smx"
rm -f "$server_dir/tf/addons/sourcemod/plugins/nextmap.smx"

# Enable mapchooser
cp "$server_dir/tf/addons/sourcemod/plugins/disabled/mapchooser.smx" "$server_dir/tf/addons/sourcemod/plugins/mapchooser.smx"
cp "$server_dir/tf/addons/sourcemod/plugins/disabled/rockthevote.smx" "$server_dir/tf/addons/sourcemod/plugins/rockthevote.smx"
cp "$server_dir/tf/addons/sourcemod/plugins/disabled/nominations.smx" "$server_dir/tf/addons/sourcemod/plugins/nominations.smx"

# Install misc plugins and disable FollowtfServerGuidelines to allow plugins that modify gameplay
#install_layer "MiscPlugins"
sed -i -E "s/(\"FollowtfServerGuidelines\"[[:space:]]+)\"[^\"]+\"/\1\"no\"/" "$server_dir/tf/addons/sourcemod/configs/core.cfg"

# Install SBPP and set serverid, also remove basebans
install_layer "SBPP"
sed -i "s/\"ServerID\"\s*\"[^\"]*\"/\"ServerID\"\t\t\"${SBPP_SERVERID}\"/" "$server_dir/tf/addons/sourcemod/configs/sourcebans/sourcebans.cfg"
rm "$server_dir/tf/addons/sourcemod/plugins/basebans.smx"

# Config general databases
append_database "default" "$DB_DRIVER" "$DB_HOST" "$DB_PORT" "$DB_SHARED_NAME" "$DB_USER" "$DB_PASS" "0"
append_database "storage-local" "$DB_DRIVER" "$DB_HOST" "$DB_PORT" "$DB_SHARED_NAME" "$DB_USER" "$DB_PASS" "0"
append_database "clientprefs" "$DB_DRIVER" "$DB_HOST" "$DB_PORT" "$DB_SHARED_NAME" "$DB_USER" "$DB_PASS" "30"
append_database "no_dupe_account" "$DB_DRIVER" "$DB_HOST" "$DB_PORT" "$DB_SHARED_NAME" "$DB_USER" "$DB_PASS" "0"
append_database "sourcebans" "$DB_DRIVER" "$DB_HOST" "$DB_PORT" "$DB_SHARED_NAME" "$DB_USER" "$DB_PASS" "0"

# Install whitelist layer if whitelist is enabled
if [[ "$WHITELIST" == "true" ]]; then
    install_layer "whitelist"
    mkdir -p "mounts/$ID/whitelist"
    install_mount "$ID/whitelist" "addons/sourcemod/configs/whitelist"
fi

# Enable auto bunnyhopping if ABH is enabled
if [[ "$ABH" == "true" ]]; then
    cat <<EOF >> "$server_dir/tf/cfg/server.cfg"

    sv_cheats 1
    sv_autobunnyhopping 1
    sv_cheats 0
EOF
fi

# Mount mapcycle
install_mount "mapcycle.txt" "mapcycle.txt"

# Only mount custom maps folder if it has content, otherwise keep base game maps
if [ "$(ls -A /mounts/maps 2>/dev/null)" ]; then
    install_mount "maps" "maps"
fi

# Mount ban cfg files
install_mount "banned_user.cfg" "cfg/banned_user.cfg"
install_mount "banned_ip.cfg" "cfg/banned_ip.cfg"

# Mount sqlite databases
install_mount "$ID/sqlite" "addons/sourcemod/data/sqlite"

# Mount logs
install_mount "$ID/logs/tf" "logs"
install_mount "$ID/logs/sourcemod" "addons/sourcemod/logs"

# Generate databases.cfg with earlier configured database credentials
cat <<EOF > "$server_dir/tf/addons/sourcemod/configs/databases.cfg"
"Databases"
{
    "driver_default"		"mysql"
    $(echo -e "$databases_cfg")
}
EOF

# Finally, launch the server
"$server_dir/srcds_linux" -game tf2 -usercon -strictportbind -ip "$IP" -port "$PORT" -nobreakpad -nowatchdog -nohltv -noautoupdate -tickrate $TICKRATE $EXTRA_LAUNCH_OPTS -apikey "$WS_APIKEY" -maxplayers_override 64 +sv_setsteamaccount "$actual_gslt" +map "$MAP" +exec "server.cfg"
