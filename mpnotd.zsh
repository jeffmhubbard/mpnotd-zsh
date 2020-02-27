#!/usr/bin/env zsh

# song info notifications for mpd
# extbin: mpc curl convert jq sed notify-send cava md5sum

APP_NAME="mpnotd"

RC_FILE="$HOME/.config/$APP_NAME/config"
CACHE_DIR="$HOME/.cache/$APP_NAME"

POPUP_TITLE=" Now Playing"
POPUP_TIME=30
POPUP_TYPE=low

CAVA_ENABLED=false
CAVA_CFG="$HOME/.config/cava/config"

# fetch cover art
function fetch_cover() {

  local cur_song=$1
  local search_url
  local cover_url

  # find cover art
  COVER_CUR=$CACHE_DIR/$(_get_hash $cur_song).jpg
  if [ -f $COVER_CUR ]
  then
    # found cached image
    [[ $DEBUG -eq 1 ]] && echo "Using cached cover: $COVER_CUR"
  else
    # create search URL
    search_url="http://api.deezer.com/search/autocomplete?q=$cur_song" && search_url=${search_url//' '/'%20'}

    # parse JSON for cover art URL
    cover_url=$(curl -s "$search_url" | jq -r '.tracks.data[0].album.cover_medium')

    # fetch cover
    curl -o $COVER_CUR -s $cover_url
    [[ $DEBUG -eq 1 ]] && echo "Fetched cover: $COVER_CUR"
  fi

}

# return hash from song info
function _get_hash() { echo -n $1 | md5sum | cut -d' ' -f1 }

# show notification
function show_popup() {

  local title=$POPUP_TITLE
  local body=$1
  local icon=$COVER_CUR
  local time=$POPUP_TIME
  local urgency=$POPUP_TYPE

  ((time = $time * 600))

  if ! notify-send -a $APP_NAME $title $body -i $icon -t $time -u $urgency
  then
    return 1
  fi

}

# set cava foreground color
function cava_color() {

  local color=$1

  if [ -z $color ]
  then
    color=$CAVA_ORIG
  fi

  if [ -f $CAVA_CFG ]
  then
    sed -i "s/^foreground.*$/foreground = '$color'/g" $CAVA_CFG
    [[ $DEBUG -eq 1 ]] && echo "Set CAVA color to '$color'"
    pkill -USR2 cava &
  fi

}

# get original cava color
function _cache_color() {

  grep foreground $CAVA_CFG | \
    awk -F" = " '{print $2}' | \
    tr -d "'"

}

# get dominant color from cover art
function _get_dominant_color() {

  local histogram
  local color
  
  if [ -f $COVER_CUR ]
  then
    histogram=$(convert $COVER_CUR -format %c -depth 8 histogram:info:)
    color=($(echo $histogram | sort -n | tail -n 1))
    echo ${color[3]}
  fi

}

# kill running instance
function _clean() {

  local pid=$$
  local pidfile=$CACHE_DIR/pid

  if [ -f $pidfile ]
  then
    oldpid=$(head -n 1 $pidfile)
    if [[ ! $pid == $oldpid ]]
    then
      kill -9 $oldpid 2>/dev/null
    fi
  fi

  echo $pid > $pidfile

}

# main loop
function main() {

  local cur_song
  local -a fields

  while true; do

    # get current cur_song
    cur_song=$(mpc current)
    [[ $DEBUG -eq 1 ]] && echo "Playing: $cur_song"

    # empty, do nothing
    if [ -z $cur_song ]
    then
      continue
    fi

    # fetch cover art
    fetch_cover $cur_song

    # construct notification
    fields=( ${(s: - :)cur_song} )
    message="${fields[2]}\n"
    message+="By ${fields[1]}"
    if [ ${#fields} -gt 2 ]
    then
      message+="\nFrom ${fields[3]}"
    fi

    # display notification and run extras
    if show_popup $message
    then
      # extras
      [[ $CAVA_ENABLED == true ]] && cava_color $(_get_dominant_color)
    fi

    # wait for cur_song to change
    while true; do
      mpc idle player &>/dev/null && (mpc status | grep "\[playing\]" &>/dev/null) && break
    done

  done

}

# help message
function usage() {

  echo "Usage: $APP_NAME [-t <SECONDS>] [-u <URGENCY>] [-c]"
  echo
  echo "optional:"
  echo "   -h, --help        show this help message and exit"
  echo "   --config          specify path to config file"
  echo "   --time            time (in seconds) to display popup"
  echo "   --urgency         popup urgency (low, normal, critical)"
  echo "   --cava            enable changing CAVA color"
  echo

}

# kill others
_clean

# parse arguments
for arg in $@
do
  case $arg in
    --config)
      RC_FILE=$2
      shift 2;;
    -t | --time)
      POPUP_TIME=$2
      shift 2;;
    -u | --urgency)
      POPUP_TYPE=$2
      shift 2;;
    -c | --cava)
      CAVA_ENABLED=true
      shift;;
    -h | --help)
      usage
      exit 0;;
  esac
done

# create cache directory
if [ ! -d $CACHE_DIR ]
then
  [[ $DEBUG -eq 1 ]] && echo "Creating cache: $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
fi

# load config
if [ -f $RC_FILE ]
then
  [[ $DEBUG -eq 1 ]] && echo "Loading config: $RC_FILE"
  source $RC_FILE
fi

# start with previous cava color
if [[ $CAVA_ENABLED == true ]]
then
  CAVA_ORIG=$(_cache_color)
fi

main

exit 0

# vim: set ft=zsh ts=2 sw=0 et:
