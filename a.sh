#!/bin/bash
set -eu

GREEN="\033[01;32m"
RED="\033[01;31m"
GRAY="\033[01;30m"
DARKYELLOW="\033[33m"
NORMAL="\033[00m"

function log_error()    { echo -e  "$RED[E]$NORMAL $*" 1>&2;   }
function log_warn()     { echo -e  "$DARKYELLOW[W]$NORMAL $*"; }
function log_info()     { echo -e  "$GREEN[I]$NORMAL $*";      }
function log_progress() { echo -en "$GRAY[>]$NORMAL $*";       }
function log_debug()    { echo -e  "$GRAY[ ]$NORMAL $*";       }

CONFIG_FILE=config
ATTIC_DIR=$HOME/.attic
KEY_DIR=$ATTIC_DIR/keys
CONFIG_DIR=$ATTIC_DIR/configs

while getopts ":c:" OPTION ; do
  case $OPTION in
    c)
      shift
      CONFIG_FILE="$1"
      ;;
  esac
  shift 
done

CONFIG_FILE="$CONFIG_DIR"/"$CONFIG_FILE"

log_debug "Using configuration in '$CONFIG_FILE'"

if [ -f "$CONFIG_FILE" ]; then
  log_info "Obtaining configuration from '$CONFIG_FILE"
  source "$CONFIG_FILE"
else
  log_warn "Configuration file '$CONFIG_FILE' not found. Trying default values"
fi

HOST=$(hostname -s)
REPOSITORY=${REPOSITORY:-/Backups/$HOST}
DATE=$(date +%Y%m%d%H%M%S)
BACKUP_SOURCES=${BACKUP_SOURCES:-/}

#Default settings for purging backups
HOURLY=${HOURLY:-24}
DAILY=${DAILY:-7}
WEEKLY=${WEEKLY:-4}
MONTHLY=${MONTHLY:-12}
YEARLY=${YEARLY:-10}

function usage() {
#Usage: $0 init|check|change-passphrase|backup|extract|delete|list|mount|info|prune|help
cat << EOF
Usage: $0 list-configs|config|init|backup|delete|list-repo|list-archive|info|help|show-key
EOF
}

case "${1:-}" in
  show-key)
    KEY=$(grep "id = " "$REPOSITORY/config" | sed 's#id = ##' )
    find "$KEY_DIR" -maxdepth 1 -type f -print0 | while IFS="" read -r -d "" keyfile; do
      if ( grep "$KEY" "$keyfile" > /dev/null ); then
         cat "$keyfile"
      fi
    done
    ;;
  list-configs)
    log_info "Listing configurations"
    find "$CONFIG_DIR" -maxdepth 1 -type f -print0 | while IFS="" read -r -d "" config; do 
        NAME=$(basename "$config")
        log_info "CONFIGURATION: $NAME"
        cat "$config"
        log_debug " ---- "
        log_debug ""
      done
    log_info "End of configuration listing"
    ;;
  config)
    log_info "Current configuration: "
    log_info "Hostname:             $HOST"
    log_info "Repository:           $REPOSITORY"
    log_info "Locations to back up: $BACKUP_SOURCES"
    log_info "Purge configuration:"
    log_info "  $HOURLY hourly backups"
    log_info "  $DAILY daily backups"
    log_info "  $WEEKLY weekly backups"
    log_info "  $MONTHLY monthly backups"
    log_info "  $YEARLY yearly backups"
    log_info "are kept"
    ;;
  init)
    attic init -e keyfile "$REPOSITORY" || { log_error "Could not initialize attic repository at $REPOSITORY"; exit 1; }
    ;;
  backup)
    log_info "Beginning backup of the mount points at: '$BACKUP_SOURCES' to '$REPOSITORY'"
    REPO_WITH_UNDERSCORES=$(echo "$REPOSITORY" | sed "s#^/##" | sed "s#/#_#g" )
    EXCLUDE_FILE=$HOME/.attic/${REPO_WITH_UNDERSCORES}.exclude
    [ -f "$EXCLUDE_FILE" ] || { log_warn "Exclude file '$EXCLUDE_FILE' not found, creating empty one"; touch "$EXCLUDE_FILE"; }
    log_debug "Parameters: REPO: $REPOSITORY; ARCHIVE: $HOST-$DATE; SOURCE: '$BACKUP_SOURCES'"
    echo "$BACKUP_SOURCES" | awk '{ for(i = 1; i <= NF; i++) { print $i; } }' | xargs attic create \
      --stats \
      --checkpoint-interval 300 \
      --exclude-caches \
      --do-not-cross-mountpoints \
      --exclude-from "$EXCLUDE_FILE" \
      "$REPOSITORY::$HOST-$DATE" || { log_error "Backup failed"; exit 3; }
    log_info "Backup completed, beginning purging of old backups"
    attic prune -v "$REPOSITORY" --keep-hourly="$HOURLY" --keep-daily="$DAILY" --keep-weekly="$WEEKLY" --keep-monthly="$MONTHLY" --keep-yearly="$YEARLY" || { log_error "Pruning failed!"; exit 5; }
    log_info "Purging of '$BACKUP_SOURCES' completed successfully" 
    ;;
  list-repo)
    log_info "Obtaining repository list from $REPOSITORY:"
    attic list "$REPOSITORY"
    ;;
  list-archive)
    [ -z "${2:-}" ] && { log_error "Missing timestamp in format YYYYMMDDHH"; exit 2; }
    ARCHIVE=$REPOSITORY::$HOST-$2
    log_info "Obtaining archive list from $ARCHIVE:"
    attic list "$ARCHIVE" || { log_error "Could not obtain archive information for $ARCHIVE on repository $REPOSITORY"; exit 4; }
    ;;
  delete)
    [ -z "${2:-}" ] && { log_error "Missing timestamp in format YYYYMMDDHH"; exit 2; }
    ARCHIVE=$REPOSITORY::$HOST-$2
    log_info "Removing $ARCHIVE"
    attic delete "$ARCHIVE" || { log_error "Could not obtain archive information for $ARCHIVE on repository $REPOSITORY"; exit 4; }
    ;;
  info)
    [ -z "${2:-}" ] && { log_error "Missing timestamp in format YYYYMMDDHH"; exit 2; }
    ARCHIVE=$REPOSITORY::$HOST-$2
    log_info "Obtaining archive information from $ARCHIVE:"
    attic info "$ARCHIVE" || { log_error "Could not obtain archive information for $ARCHIVE on repository $REPOSITORY"; exit 4; }
    ;;
  *)
    usage
    exit 1
    ;;
esac

exit 0
