#!/usr/bin/env zsh

# song info notifications for mpd
# extbin: mpc curl convert jq sed notify-send cava md5sum

APP_NAME="mpnotd"

# defaults
RC_FILE=$HOME/.config/$APP_NAME/config
CACHE_DIR=$HOME/.cache/$APP_NAME
COVER_CUR=$CACHE_DIR/current.jpg

POPUP_TITLE=" Now Playing"
POPUP_TIME=30
POPUP_LEVEL=low

CAVA_ENABLED=false
CAVA_CFG=$HOME/.config/cava/config

# fetch cover art
function fetch_cover() {

  local cur_song=$1
  local search_url
  local cover_url

  COVER_ART=$CACHE_DIR/$(_get_hash $cur_song).jpg

  if [ -f $COVER_ART ]
  then
    [[ $DEBUG -gt 0 ]] && echo "Using cached cover: $COVER_ART"
  else
    [[ $DEBUG -gt 0 ]] && echo "Finding cover for: $cur_song"

    search_url="http://api.deezer.com/search/autocomplete?q=$cur_song" && search_url=${search_url//' '/'%20'}
    [[ $DEBUG -gt 0 ]] && echo "Search URL: $search_url"

    cover_url=$(curl -s "$search_url" | jq -r '.tracks.data[0].album.cover_medium')
    [[ $DEBUG -gt 0 ]] && echo "Cover URL: $cover_url"

    curl -o $COVER_ART -s $cover_url
    [[ $DEBUG -gt 0 ]] && echo "File path: $COVER_ART"
  fi

  cp $COVER_ART $COVER_CUR 2>/dev/null

}

# return md5 hash from string
function _get_hash() { echo -n $1 | md5sum | cut -d ' ' -f 1 }

# show notification
function show_popup() {

  local title=$POPUP_TITLE
  local body=$1
  local icon=$COVER_ART
  local time=$POPUP_TIME
  local urgency=$POPUP_LEVEL

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
    dcolor=$(_get_dominant_color $COVER_ART)
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
    awk -F" = " '{print $2}' | \
    tr -d "'"

}

# get dominant hex color from image
function _get_dominant_color() {

  local infile=$1
  local histogram
  local color
  
  if [ -f $infile ]
  then
    histogram=$(convert $infile -format %c -depth 8 histogram:info:)
    color=($(echo $histogram | sort -n | tail -n 1))
    echo ${color[3]:gs/#/}
  fi

}

# return color from $CAVA_COLORS that is closest to $incolor
function _get_palette_match() {

    local incolor=$1

    for (( i = 1; i <= $#CAVA_COLORS; i++ ))
    do
      echo "$(_color_dist $incolor $CAVA_COLORS[$i]) $CAVA_COLORS[$i]"
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

# kill running instance
function clean_run() {

  local pid=$$
  local pidfile=$CACHE_DIR/pid
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

# main loop
function main() {

  local cur_song
  local -a fields

  while true
  do

    cur_song=$(mpc current)

    if [ -z $cur_song ]
    then
      [[ $DEBUG -gt 0 ]] && echo "Could not get current song info..."
      continue
    fi

    [[ $DEBUG -gt 0 ]] && echo "Playing: $cur_song"

    fetch_cover $cur_song

    fields=( ${(s: - :)cur_song} )
    message="$fields[2]\n"
    message+="By $fields[1]"
    if [ $#fields -gt 2 ]
    then
      message+="\nFrom $fields[3]"
    fi

    if show_popup $message
    then
      [[ $DEBUG -gt 0 ]] && echo "Running extras..."
      [[ $CAVA_ENABLED == true ]] && cava_color
    fi

    while true
    do
      [[ $DEBUG -gt 0 ]] && echo "Waiting..."
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
  echo "   -t, --time        time (in seconds) to display popup"
  echo "   -u, --urgency     popup urgency (low, normal, critical)"
  echo "   -c, --cava        enable changing CAVA color"
  echo

}

# kill others
clean_run

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
      POPUP_LEVEL=$2
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
  [[ $DEBUG -gt 0 ]] && echo "Creating cache: $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
fi

# load config
if [ -f $RC_FILE ]
then
  [[ $DEBUG -gt 0 ]] && echo "Loading config: $RC_FILE"
  source $RC_FILE
fi

# save original cava color
if [[ $CAVA_ENABLED == true ]]
then
  CAVA_ORIG=$(_cava_cur_color)
fi

main

exit 0

# vim: set ft=zsh ts=2 sw=0 et:
