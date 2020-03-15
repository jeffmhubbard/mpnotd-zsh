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
CACHE_DAYS=10
MUSIC_DIR=$HOME/Music
COVER_ART=$CACHE_DIR/current.jpg
STOCK_ART=$CACHE_DIR/stock.jpg

###########################################################
# core

# main
function main() {
  local RUN_ONCE=true
  local cache_enc

  while true
  do
    [[ $DEBUG -gt 0 ]] && \
      { printf -- '-%.0s' $(seq 50); echo -n "\n--------- $(date) --------\n" }

    # clear previous song
    unset SONG

    # get current song info
    if get_current_song
    then

      # create cache path
      cache_enc=$(_get_hash "${SONG[artist]} - ${SONG[album]}")
      SONG[cover]=$CACHE_DIR/cover-$cache_enc.jpg
      [[ $DEBUG -gt 0 ]] && echo "Core: Cache to: ${SONG[cover]}"

      # get cover
      get_current_cover

      # actions
      [[ $DEBUG -gt 0 ]] && echo "Core: Actions..."
      run_actions

    else
      [[ $DEBUG -gt 0 ]] && echo "Core: Unable to get song info..."
      cp $STOCK_ART $COVER_ART
    fi

    RUN_ONCE=false

    # now we wait
    while true
    do
      [[ $DEBUG -gt 0 ]] && echo "Core: Waiting..."
      mpc idle player &>/dev/null && (mpc status | grep "\[playing\]" &>/dev/null) && break
    done

    sleep 1

  done
}

# get current song
function get_current_song() {
  local current
  typeset -Ag SONG

  current=("${(f@)$(mpc current -f "%file%\n%title%\n%artist%\n%album%\n%date%\n%genre%\n%track%\n%time%\n%position%]")}")

  SONG[url]=${current[1]:-null}
  SONG[title]=${current[2]:-null}
  SONG[artist]=${current[3]:-null}
  SONG[album]=${current[4]:-null}
  SONG[date]=${current[5]:-null}
  SONG[genre]=${current[6]:-null}
  SONG[track]=${current[7]:-null}
  SONG[time]=${current[8]:-null}
  SONG[position]=${current[9]:-null}

  [[ ${SONG[url]} == null ]] && return 1
  [[ ${SONG[title]} == null ]] && return 1
  [[ ${SONG[artist]} == null ]] && return 1
  [[ ${SONG[album]} == null ]] && return 1

  [[ $DEBUG -gt 0 ]] && { \
    for key val in ${(kv)SONG}
    do
      echo "Core: Current: $key = $val"
    done
  }

  return 0
}

# simple hash to generate cache filenames
function _get_hash() { echo -n $1 | md5sum | cut -d ' ' -f 1 }

# try to find cover locally or online
# otherwise use stock image
function get_current_cover() {
  local searchpath

  if [[ ! -f ${SONG[cover]} ]]
  then

    # if we find a URL, just make up local path
    if [[ ${SONG[url]} == http* ]]
    then
      searchpath=$MUSIC_DIR/${SONG[artist]}/${SONG[album]}
    else
      searchpath=$MUSIC_DIR/${SONG[url]:t}
    fi

    # if we don't find locally, search deezer
    if ! find_local_image $searchpath
    then
      find_deezer_image
    fi
  else
    [[ $DEBUG -gt 0 ]] && echo "Core: Cover exists: ${SONG[cover]}"
  fi

  # copy image to current.jpg
  if [[ -f ${SONG[cover]} ]]
  then
    cp ${SONG[cover]} $COVER_ART
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
        cp $artwork ${SONG[cover]}
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
      --data-urlencode "q=artist:\"${SONG[artist]}\" album:\"${SONG[album]}\"" | \
      jq -r '.data[0].album.cover_medium')

  [[ $DEBUG -gt 0 ]] && echo "Core: Cover URL: $result"
  if curl -s $result -o ${SONG[cover]}
  then
    [[ $DEBUG -gt 0 ]] && echo "Core: Got cover!"
    return 0
  fi

  [[ $DEBUG -gt 0 ]] && echo "Core: No cover found!"
  return 1
}

###########################################################
# popup

POPUP_ENABLE=true
POPUP_SUBJECT=" Now Playing"
POPUP_DURATION=10
POPUP_LEVEL=low

function init_popup() { return }

# display notification
function action_popup() {
  local icon=$COVER_ART
  local subject=$POPUP_SUBJECT
  local duration=$POPUP_DURATION
  local urgency=$POPUP_LEVEL
  local body

  for key val in ${(kv)SONG}
  do
    local ${key}=$val
  done

  body="$title\nBy $artist\nFrom $album ($date)"

  if (( ${+POPUP_BODY} ))
  then
    for tag in ${(k)SONG}
    do
      match="%${tag}%"
      replace=$SONG[$tag]
      POPUP_BODY=${POPUP_BODY/$match/$replace}
    done
  fi

  ((duration = $duration * 1000))

  [[ $DEBUG -gt 0 ]] && echo "Popup: Sending now..."
  if ! notify-send -a ${APP_NAME} ${subject} ${POPUP_BODY:-$body} \
    -i ${icon} -t ${duration} -u ${urgency}
  then
    [[ $DEBUG -gt 0 ]] && echo "Popup: Sending failed!"
    return 1
  fi

  return 0
}

###########################################################
# cava

CAVA_ENABLE=false
CAVA_CFG=$HOME/.config/cava/config

function init_cava() {
  # save original cava color
  if [[ $CAVA_ENABLE == true ]]
  then
    CAVA_ORIG=$(_cava_cur_color)
    [[ $DEBUG -gt 0 ]] && echo "Cava: Original color: $CAVA_ORIG"
  fi
}

# set cava foreground color
function action_cava() {
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
    local red=$(echo "var=$color1[1]-$color2[1];var*var" | bc)
    local green=$(echo "var=$color1[2]-$color2[2];var*var" | bc)
    local blue=$(echo "var=$color1[3]-$color2[3];var*var" | bc)
    echo "sqrt ( $red + $green + $blue )" | bc
}

# convert hex color (without #) to rgb (128 128 128)
function _hex2rgb() { echo $((16#${1:0:2})) $((16#${1:2:2})) $((16#${1:4:2})) }

###########################################################
# cover

COVER_ENABLE=false
COVER_SIZE=200x200
COVER_POSITION=+20+20

function init_cover() {
  # make feh exit with script
  if [[ $COVER_ENABLE == true ]]
  then
    trap exit_cover EXIT
  fi
}

# show cover art
function action_cover() {
  [[ -n $COVER_DURATION ]] && { local RUN_ONCE=true; exit_cover; }

  if [[ $RUN_ONCE == true ]]
  then
    # start feh, write pid
    ( feh --class $APP_NAME -g $COVER_SIZE$COVER_POSITION -xZ. $COVER_ART )&|
    echo $! >$CACHE_DIR/cover.pid
    [[ $DEBUG -gt 0 ]] && echo "Cover: Started feh..."

    # if set, kill feh after duration
    [[ -n $COVER_DURATION ]] && ( sleep $COVER_DURATION; exit_cover; )&|
  fi
}

# kill feh using pid file
function exit_cover() { kill -9 $(cat $CACHE_DIR/cover.pid) &> /dev/null }

###########################################################
# write out

WRITE_ENABLE=false
WRITE_FILE=$CACHE_DIR/current.txt

function init_write() {
  if [[ ! -f $WRITE_FILE ]]
  then
    touch $WRITE_FILE 2> /dev/null
  fi
}

function action_write() {
  local separator="|"
  local output

  [[ $DEBUG -gt 0 ]] && echo "Write: Output to: $WRITE_FILE"

  if [[ -f $WRITE_FILE ]]
  then
    for key val in ${(kv)SONG}
    do
      # key and value with separator
      output+="$key${WRITE_SEP:-$separator}$val\n"
    done

    # overwrite existing file
    echo -n $output > $WRITE_FILE

    return 0
  fi

  return 1
}

###########################################################

function load_config() {
  if [ -f $RC_FILE ]
  then
    source $RC_FILE
    [[ $DEBUG -gt 0 ]] && echo "Core: Loaded config: $RC_FILE"
  fi
}

# create cache directory
function check_cache() {
  if [ ! -d $CACHE_DIR ]
  then
    mkdir -p "$CACHE_DIR"
    [[ $DEBUG -gt 0 ]] && echo "Core: Created cache: $CACHE_DIR"
  fi
}

# purge cached covert art
function purge_cache() {
  local pattern="cover-*.jpg"

  if [ -d $CACHE_DIR ]
  then
    if find $CACHE_DIR -name "$pattern" -type f -mtime +$CACHE_DAYS -exec rm -f {} \;
    then
      [[ DEBUG -gt 0 ]] && echo "Core: Purged cache: $CACHE_DAYS days"
    fi
  fi
}

# create stock image to use when cover art isn't found
function make_stock_art() {
  if [ ! -f $STOCK_ART ]
  then
    magick -size 64x64 gradient:blue-black $STOCK_ART
    [[ DEBUG -gt 0 ]] && echo "Core: Created stock image: $STOCK_ART"
  fi
}

# executes functions starting with init_
function init_actions() {
  local -a myfuncs=($(typeset +f))
  local init
  for init in $myfuncs
  do
    local toggle="${(U)init/init_/}_ENABLE"
    [[ $init == $'init_'* &&  ${(P)toggle} == true ]] && { $init & }
  done
}

# executes functions starting with action_
function run_actions() {
  local -a myfuncs=($(typeset +f))
  local action
  for action in $myfuncs
  do
    local toggle="${(U)action/action_/}_ENABLE"
    [[ $action == $'action_'* &&  ${(P)toggle} == true ]] && { $action & }
  done
}

# look for pid files in cache directory
# if processes still running, kill them
# then write new pid
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

  [[ DEBUG -gt 0 ]] && echo "Core: Writing new PID: $pid"
  echo $pid > $pidnew
}

# help message
function usage() {
  echo "Usage: $APP_NAME [-t <SECONDS>] [-u <URGENCY>] [-v] [-c]"
  echo
  echo "optional:"
  echo "  -C, --config      specify path to config file"
  echo "  -p, --popup       enable popup (on by default)"
  echo "  -t, --time        time (in seconds) to display popup"
  echo "  -u, --urgency     popup urgency (low, normal, critical)"
  echo "  -v, --cava        enable changing cava color"
  echo "  -c, --cover       enable cover mode"
  echo "  -w, --write       enable output file"
  echo "  -D, --debug       verbose output"
  echo "  -h, --help        show this help message and exit"
  echo
}

###########################################################
# main

load_config
check_cache
purge_cache
make_stock_art

# parse arguments
for arg in $@
do
  case $arg in
    -C | --config)
      RC_FILE=$2
      load_config
      break;;
    -p | --popup)
      POPUP_ENABLE=true
      shift;;
    -t | --time)
      POPUP_DURATION=$2
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
    -w | --write)
      WRITE_ENABLE=true
      WRITE_FILE=$2
      shift 2;;
    -D | --debug)
      DEBUG=1
      shift;;
    -h | --help)
      usage
      exit 0;;
  esac
done

init_actions

clean_run

main

exit 0

# vim: set ft=zsh ts=2 sw=0 et:
