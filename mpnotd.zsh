#!/usr/bin/env zsh

# song info notifications for mpd
# extbin: mpc curl convert jq sed notify-send cava md5sum

APP_NAME="mpnotd"

# defaults
RC_FILE=$HOME/.config/$APP_NAME/config
CACHE_DIR=$HOME/.cache/$APP_NAME
CACHE_AGE=10
COVER_CUR=$CACHE_DIR/current.jpg
STOCK_ART=$CACHE_DIR/stock.jpg


POPUP_ENABLE=true
POPUP_TITLE=" Now Playing"
POPUP_TIME=10
POPUP_LEVEL=low

CAVA_ENABLE=false
CAVA_CFG=$HOME/.config/cava/config

COVER_ENABLE=false
COVER_SIZE=200x200
COVER_POSITION=+1680+820

# load config
if [ -f $RC_FILE ]
then
  [[ $DEBUG -gt 0 ]] && echo "Loading config: $RC_FILE"
  source $RC_FILE
fi

# create cache directory
if [ ! -d $CACHE_DIR ]
then
  [[ $DEBUG -gt 0 ]] && echo "Creating cache: $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
fi

# main
function main() {

  local cur_song
  local RUN_ONCE=true

  while true
  do

    cur_song=$(mpc current)

    if [ -z $cur_song ]
    then
      [[ $DEBUG -gt 0 ]] && echo "Could not get current song info..."
      continue
    fi

    [[ $DEBUG -gt 0 ]] && echo "Playing: $cur_song"

    get_cover_art $cur_song

    [[ $POPUP_ENABLE == true ]] && show_popup $cur_song
    [[ $CAVA_ENABLE == true ]] && cava_color
    [[ $COVER_ENABLE == true ]] && show_cover

    while true
    do
      [[ $DEBUG -gt 0 ]] && echo "Waiting..."
      mpc idle player &>/dev/null && (mpc status | grep "\[playing\]" &>/dev/null) && break
    done

    RUN_ONCE=false

  done

}

# get cover art
function get_cover_art() {

  local song=$1

  COVER_ART=$CACHE_DIR/cover-$(_get_hash $song).jpg

  if [ -f $COVER_ART ]
  then
    [[ $DEBUG -gt 0 ]] && echo "Using cached cover: $COVER_ART"
  else
    fetch_cover $song
  fi

  if [ -f $COVER_ART ]
  then
    cp $COVER_ART $COVER_CUR 2>/dev/null
  else
    cp $STOCK_ART $COVER_CUR 2>/dev/null
  fi

}

# fetch cover art
function fetch_cover() {

  local song=$1
  local search_url
  local cover_url

  search_url="http://api.deezer.com/search/autocomplete?q=$song" && search_url=${search_url//' '/'%20'}
  [[ $DEBUG -gt 0 ]] && echo "Search URL: $search_url"

  cover_url=$(curl -s "$search_url" | jq -r '.tracks.data[0].album.cover_medium')
  [[ $DEBUG -gt 0 ]] && echo "Cover URL: $cover_url"

  curl -o $COVER_ART -s $cover_url
  [[ $DEBUG -gt 0 ]] && echo "File path: $COVER_ART"

}

# return md5 hash from string
function _get_hash() { echo -n $1 | md5sum | cut -d ' ' -f 1 }

# create stock image to use when cover art isn't found
function make_stock_art() {
  magick -size 64x64 gradient: $STOCK_ART
  magick -size 64x64 gradient:blue-black $STOCK_ART
}

# show notification
function show_popup() {

  local cur_song=$1
  local title=$POPUP_TITLE
  local body
  local icon=$COVER_ART
  local time=$POPUP_TIME
  local urgency=$POPUP_LEVEL
  local fields

  fields=( ${(s: - :)cur_song} )
  body="$fields[2]\n"
  body+="By $fields[1]"
  if [ $#fields -gt 2 ]
  then
    body+="\nFrom $fields[3]"
  fi

  ((time = $time * 1000))

  [[ $DEBUG -gt 0 ]] && echo "Sending notification..."
  if ! notify-send -a $APP_NAME $title $body -i $icon -t $time -u $urgency
  then
    [[ $DEBUG -gt 0 ]] && echo "Notification failed!"
    return 1
  fi

}

# set cava foreground color
function cava_color() {

  if [ -f $CAVA_CFG ]
  then
    dcolor=$(_get_dominant_color $COVER_CUR)
    [[ $DEBUG -gt 0 ]] && echo "Got dominant color '$dcolor'"

    if [ -z $dcolor ]
    then
      dcolor=$CAVA_ORIG
      [[ $DEBUG -gt 0 ]] && echo "Bad color, using original: $CAVA_ORIG"
    fi

    if (( ${+CAVA_COLORS} ))
    then
      pcolor=$(_get_palette_match $dcolor)
      [[ $DEBUG -gt 0 ]] && echo "Got palette color '$pcolor'"
    fi

    sed -i "s/^foreground.*$/foreground = '#${pcolor:-$dcolor}'/g" $CAVA_CFG
    [[ $DEBUG -gt 0 ]] && echo "Set CAVA color to '${pcolor:-$dcolor}'"

    [[ $DEBUG -gt 0 ]] && echo "Restarting CAVA..."
    pkill -USR2 cava &
  else
    [[ $DEBUG -gt 0 ]] && echo "Could not locate CAVA config: $CAVA_CFG"
  fi

}

# get cava foreground color
function _cava_cur_color() {

  grep foreground $CAVA_CFG | \
    awk -F " = " '{print $2}' | \
    tr -d "'"

}

# get dominant hex color from image
function _get_dominant_color() {

  local infile=$1
  local histogram
  local color
  
  if [ -f $infile ]
  then
    histogram=$(magick $infile -format %c -depth 8 histogram:info:)
    color=($(echo $histogram | sort -n | tail -n 1))
    echo ${color[3]:gs/#/}
  fi

}

# return color from $CAVA_COLORS that is closest to $incolor
function _get_palette_match() {

    local incolor=$1
    local pcolor

    for pcolor in $CAVA_COLORS
    do
      echo "$(_color_dist $incolor $pcolor) $pcolor"
    done | sort -g | head -n 1 | cut -d ' ' -f 2

}

# calculate distance between two hex colors
# https://en.wikipedia.org/wiki/Color_difference
function _color_dist() {
    local color1=($(_hex2rgb $1))
    local color2=($(_hex2rgb $2))
    local minr=$(echo "$color1[1] - $color2[1]" | bc)
    local ming=$(echo "$color1[2] - $color2[2]" | bc)
    local minb=$(echo "$color1[3] - $color2[3]" | bc)
    local sqr=$(echo "$minr * $minr" | bc)
    local sqg=$(echo "$ming * $ming" | bc)
    local sqb=$(echo "$minb * $minb" | bc)
    echo $(echo "sqrt ( $sqr + $sqg + $sqb )" | bc)
}

# convert hex color (without #) to rgb (128 128 128)
function _hex2rgb() { echo $((16#${1:0:2})) $((16#${1:2:2})) $((16#${1:4:2})) }

# show floating cover art
function show_cover() {

  [[ -n $COVER_TIME ]] && local RUN_ONCE=true

  if [[ $RUN_ONCE == true ]]; then
    ( feh --class $APP_NAME -g $COVER_SIZE$COVER_POSITION -xZ. $COVER_CUR )&|
    echo $! >$CACHE_DIR/cover.pid
    [[ -n $COVER_TIME ]] && { sleep $COVER_TIME; feh_exit; }
    [[ $DEBUG -gt 0 ]] && echo "Displaying cover art..."
  fi

}

# make feh exit with script
function feh_exit() { kill -9 $(cat $CACHE_DIR/cover.pid) &> /dev/null }

# purge cached covert art
function purge_cache() {

  local pattern="cover-*.jpg"

  if find $CACHE_DIR -name "$pattern" -type f -mtime +$CACHE_AGE -exec rm -f {} \;
  then
    [[ DEBUG -gt 0 ]] && echo "Purged covers older than: $CACHE_AGE days"
  fi

}

# kill running instance
function clean_run() {

  local pid=$$
  local pidfile=$CACHE_DIR/$APP_NAME.pid
  local oldpid

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

# help message
function usage() {

  echo "Usage: $APP_NAME [-t <SECONDS>] [-u <URGENCY>] [-c]"
  echo
  echo "optional:"
  echo "  -h, --help        show this help message and exit"
  echo "  --config          specify path to config file"
  echo "  -t, --time        time (in seconds) to display popup"
  echo "  -u, --urgency     popup urgency (low, normal, critical)"
  echo "  -c, --cava        enable changing CAVA color"
  echo

}

# kill others
clean_run

# parse arguments
for arg in $@
do
  case $arg in
    -C | --config)
      RC_FILE=$2
      shift 2;;
    -p | --popup)
      POPUP_ENABLE=true
      shift;;
    -t | --time)
      POPUP_TIME=$2
      shift 2;;
    -u | --urgency)
      POPUP_LEVEL=$2
      shift 2;;
    -v | --cava)
      CAVA_ENABLE=true
      shift;;
    -c | --cover)
      COVER_ENABLE=true
      shift;;
    -D | --debug)
      DEBUG=1
      shift;;
    -h | --help)
      usage
      exit 0;;
  esac
done

# check for stock image
[[ ! -f $STOCK_ART ]] && make_stock_art

# purge old cover art
[[ -d $CACHE_DIR ]] && purge_cache

# save original cava color
if [[ $CAVA_ENABLE == true ]]
then
  CAVA_ORIG=$(_cava_cur_color)
  [[ $DEBUG -gt 0 ]] && echo "Original CAVA color: $CAVA_ORIG"
fi

# set trap for feh
if [[ $COVER_ENABLE == true ]]
then
  trap feh_exit EXIT
fi

# go
main

exit 0

# vim: set ft=zsh ts=2 sw=0 et:
