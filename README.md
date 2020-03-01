# MPD Notification Daemon (Zsh)  
  
Watches MPD for song change and does stuff.  
  
### Features
* Display song info and cover in notification
* Change [cava](https://github.com/karlstav/cava) fg color based on cover art
* Display cover art on desktop
  
### Requirements  
zsh  
mpc  
libnotify  
curl  
jq  
sed  
imagemagick  
cava  
feh  
  
### Installation  
  
Manual:  
```sh
git clone https://github.com/jeffmhubbard/mpnotd-zsh
sudo install -Dm 755 mpnotd-zsh/mpnotd.zsh /usr/local/bin/mpnotd
```
  
### Usage  
To start from terminal:  
  `mpnotd --time 20 -u low --cava`  
  
```sh
-C, --config    specify path to config file
-t, --time      time to display popup (in seconds)
-u, --urgency   urgency level (low, normal, critical)
-v, --cava      enable cava color
-c, --cover     enable cover mode
-D, --debug     verbose output
-h, --help      print help
```
  
### Configuration  
  
```sh
# mpnotd config

# set title of popup
POPUP_TITLE=" Now Playing"

# time to display popup (seconds)
POPUP_TIME=30

# popup urgency (low, normal, critical)
POPUP_LEVEL=low

# change cava fg color based on cover art
CAVA_ENABLED=true

# (if set) palette to use instead of dominant color
CAVA_COLORS=(fc391f 31e722 eaec23 5833ff f935f8 14f0f0)

# show cover art on desktop
COVER_ENABLE=true

# cover art size
COVER_SIZE=200x200

# cover art position
COVER_POSITION=+20+20

# (if set) time to display cover art
COVER_TIME=10
```

### Notes
