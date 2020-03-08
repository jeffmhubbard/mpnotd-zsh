#!/usr/bin/env zsh
#
# mpnotd-zsh
#
# watch MPD for song change and display notification
# requires: mpc curl convert jq sed notify-send cava md5sum
#

APP_NAME=mpnotd

# defaults
RC_FILE=$HOME/.config/$APP_NAME/config
CACHE_DIR=$HOME/.cache/$APP_NAME
CACHE_AGE=10
MUSIC_DIR=$HOME/Music
COVER_ART=$CACHE_DIR/current.jpg
STOCK_ART=$CACHE_DIR/stock.jpg

# popup
POPUP_ENABLE=true
POPUP_TITLE=" Now Playing"
POPUP_TIME=10
POPUP_LEVEL=low
POPUP_PFX_TITLE=""
POPUP_PFX_ARTIST="By "
POPUP_PFX_ALBUM="From "

# cava
CAVA_ENABLE=false
CAVA_CFG=$HOME/.config/cava/config

# cover
COVER_ENABLE=false
COVER_SIZE=200x200
COVER_POSITION=+20+20

###########################################################
# core

# main
function main() {
  local RUN_ONCE=true
  local cache_enc

  while true
  do

    # get current song info
    if get_current_song
    then

      # create cache path
      cache_enc=$(_get_hash "$SONG_ARTIST - $SONG_ALBUM")
      SONG_COVER=$CACHE_DIR/cover-$cache_enc.jpg
      [[ $DEBUG -gt 0 ]] && echo "Core: Cache cover to: $SONG_COVER"

      # get cover
      get_current_cover

      # actions
      [[ $DEBUG -gt 0 ]] && echo "Core: Actions..."
      [[ $POPUP_ENABLE == true ]] && show_popup
      [[ $CAVA_ENABLE == true ]] && cava_color
      [[ $COVER_ENABLE == true ]] && show_cover

    fi

    RUN_ONCE=false

    # now we wait
    while true
    do
      [[ $DEBUG -gt 0 ]] && echo "Core: Waiting..."
      mpc idle player &>/dev/null && (mpc status | grep "\[playing\]" &>/dev/null) && break
    done

  done
}

# get current song
function get_current_song() {
  local song

  song=("${(f@)$(mpc current -f "%file%\n%title%\n%artist%\n%album%]")}")

  SONG_FILE=$song[1]
  SONG_TITLE=$song[2]
  SONG_ARTIST=$song[3]
  SONG_ALBUM=$song[4]

  if [[ -z $SONG_TITLE ]]
  then
    return 1
  fi

  [[ $DEBUG -gt 0 ]] && \
    echo "Core: Now Playing..."; \
    echo "Core: Title: $SONG_TITLE"; \
    echo "Core: Artist: $SONG_ARTIST"; \
    echo "Core: Album: $SONG_ALBUM"; \
    echo "Core: File: $SONG_FILE"

  return 0
}

# simple hash to generate cache filenames
function _get_hash() { echo -n $1 | md5sum | cut -d ' ' -f 1 }

# try to find cover locally or online
# otherwise use stock image
function get_current_cover() {
  local searchpath

  if [[ ! -f $SONG_COVER ]]
  then

    # if we find a URL, just make up local path
    if [[ $SONG_FILE == http* ]]
    then
      searchpath=$MUSIC_DIR/$SONG_ARTIST/$SONG_ALBUM
    else
      searchpath=$MUSIC_DIR/$SONG_FILE:t
    fi

    # if we don't find locally, search deezer
    if ! find_local_image $searchpath
    then
      find_deezer_image
    fi
  fi

  # copy image to current.jpg
  if [[ -f $SONG_COVER ]]
  then
    cp $SONG_COVER $COVER_ART
  else
    cp $STOCK_ART $COVER_ART
  fi

  return 0
}

# attempt to locate cover in local filesystem
function find_local_image() {
  local filepath=$1
  local common=("cover.jpg" "folder.jpg" "albumart.jpg")

  [[ $DEBUG -gt 0 ]] && echo "Core: Searching: $filepath"

  if [[ -f $filepath ]]
  then
    matches=(${(0)"$(find $filepath:h -type f -name '*.jpg')"})
    for artwork in $matches
    do
      if [[ ${common[(ie)$artwork:t]} -le ${#common} ]]
      then
        cp $artwork $SONG_COVER
        [[ $DEBUG -gt 0 ]] && echo "Core: Found cover!"
        return 0
      fi
    done
  fi

  [[ $DEBUG -gt 0 ]] && echo "Core: No cover found!"
  return 1
}

# attempt to locate cover on deezer
function find_deezer_image() {
  local result

  [[ $DEBUG -gt 0 ]] && echo "Core: Searching online!"

  result=$(curl -s -G "http://api.deezer.com/search" \
      --data-urlencode "q=artist:\"$SONG_ARTIST\" album:\"$SONG_ALBUM\"" | \
      jq -r '.data[0].album.cover_medium')

  [[ $DEBUG -gt 0 ]] && echo "Core: Cover URL: $result"
  if curl -s $result -o $SONG_COVER
  then
    [[ $DEBUG -gt 0 ]] && echo "Core: Got cover!"
    return 0
  fi

  [[ $DEBUG -gt 0 ]] && echo "Core: No cover found!"
  return 1
}

# create stock image to use when cover art isn't found
function make_stock_art() { magick -size 64x64 gradient:blue-black $STOCK_ART }

# look for pid files in cache directory
# if processes still running, kill them
function clean_run() {
  local pid=$$
  local pidnew=$CACHE_DIR/$APP_NAME.pid
  local pidlist=($(find $CACHE_DIR -name "*.pid" 2> /dev/null))
  local procs=($(pgrep -af $APP_NAME | cut -d ' ' -f 1))
  local readpid

  if [[ $#pidlist -gt 0 ]]
  then
    for pidfile in $pidlist
    do
      readpid=$(cat $pidfile)
      [[ ${procs[(ie)$readpid]} -le ${#procs} ]] && kill -9 $readpid
    done
  fi

  echo $pid > $pidnew
}

# help message
function usage() {
  echo "Usage: $APP_NAME [-t <SECONDS>] [-u <URGENCY>] [-v] [-c]"
  echo
  echo "optional:"
  echo "  -h, --help        show this help message and exit"
  echo "  -C, --config      specify path to config file"
  echo "  -p, --popup       enable popup (on by default)"
  echo "  -t, --time        time (in seconds) to display popup"
  echo "  -u, --urgency     popup urgency (low, normal, critical)"
  echo "  -v, --cava        enable changing cava color"
  echo "  -c, --cover       enable cover mode"
  echo "  -D, --debug       verbose output"
  echo
}

###########################################################
# popup

# display notification
function show_popup() {
  local icon=$COVER_ART
  local title=$POPUP_TITLE
  local time=$POPUP_TIME
  local urgency=$POPUP_LEVEL
  local body

  body="$POPUP_PFX_TITLE$SONG_TITLE\n"
  body+="$POPUP_PFX_ARTIST$SONG_ARTIST\n"
  body+="$POPUP_PFX_ALBUM$SONG_ALBUM"

  ((time = $time * 1000))

  [[ $DEBUG -gt 0 ]] && echo "Popup: Sending now..."
  if ! notify-send -a $APP_NAME $title $body -i $icon -t $time -u $urgency
  then
    [[ $DEBUG -gt 0 ]] && echo "Popup: Sending failed!"
    return 1
  fi

  return 0
}

###########################################################
# cava

# set cava foreground color
function cava_color() {
  if [ -f $CAVA_CFG ]
  then
    dcolor=$(_get_dominant_color $COVER_ART)
    [[ $DEBUG -gt 0 ]] && echo "Cava: Got dominant '$dcolor'"

    if [ -z $dcolor ]
    then
      dcolor=$CAVA_ORIG
      [[ $DEBUG -gt 0 ]] && echo "Cava: Bad color, using original: $CAVA_ORIG"
    fi

    if (( ${+CAVA_COLORS} ))
    then
      pcolor=$(_get_palette_match $dcolor)
      [[ $DEBUG -gt 0 ]] && echo "Cava: Got palette '$pcolor'"
    fi

    sed -i "s/^foreground.*$/foreground = '#${pcolor:-$dcolor}'/g" $CAVA_CFG
    [[ $DEBUG -gt 0 ]] && echo "Cava: Set color to '${pcolor:-$dcolor}'"

    [[ $DEBUG -gt 0 ]] && echo "Cava: Restarting..."
    pkill -USR2 cava &
  else
    [[ $DEBUG -gt 0 ]] && echo "Cava: Could not locate config: $CAVA_CFG"
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
# using Euclidean formula, ymmv
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

###########################################################
# cover

# show floating cover art
function show_cover() {
  [[ -n $COVER_TIME ]] && local RUN_ONCE=true

  if [[ $RUN_ONCE == true ]]
  then
    ( feh --class $APP_NAME -g $COVER_SIZE$COVER_POSITION -xZ. $COVER_ART )&|
    echo $! >$CACHE_DIR/cover.pid
    [[ -n $COVER_TIME ]] && ( sleep $COVER_TIME; feh_exit; )&|
    [[ $DEBUG -gt 0 ]] && echo "Cover: Started feh..."
  fi
}

# make feh exit with script
function feh_exit() { kill -9 $(cat $CACHE_DIR/cover.pid) &> /dev/null }

# purge cached covert art
function purge_cache() {
  local pattern="cover-*.jpg"

  if find $CACHE_DIR -name "$pattern" -type f -mtime +$CACHE_AGE -exec rm -f {} \;
  then
    [[ DEBUG -gt 0 ]] && echo "Core: Purged cache: $CACHE_AGE days"
  fi
}

###########################################################
# init main

# load config
if [ -f $RC_FILE ]
then
  source $RC_FILE
  [[ $DEBUG -gt 0 ]] && echo "Core: Loaded config: $RC_FILE"
fi

# create cache directory
if [ ! -d $CACHE_DIR ]
then
  mkdir -p "$CACHE_DIR"
  [[ $DEBUG -gt 0 ]] && echo "Core: Created cache: $CACHE_DIR"
fi

# purge old cover art
[[ -d $CACHE_DIR ]] && purge_cache

# check for stock image
[[ ! -f $STOCK_ART ]] && make_stock_art

# parse arguments
for arg in $@
do
  case $arg in
    -C | --config)
      RC_FILE=$2
      source $RC_FILE
      break;;
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

###########################################################
# init extras

# save original cava color
if [[ $CAVA_ENABLE == true ]]
then
  CAVA_ORIG=$(_cava_cur_color)
  [[ $DEBUG -gt 0 ]] && echo "Cava: Original color: $CAVA_ORIG"
fi

# set trap for feh
if [[ $COVER_ENABLE == true ]]
then
  trap feh_exit EXIT
fi

###########################################################
# main

clean_run

main

exit 0

# vim: set ft=zsh ts=2 sw=0 et:
