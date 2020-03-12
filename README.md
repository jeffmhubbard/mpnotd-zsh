# MPD Notification Daemon (Zsh)  
  
![Demo Animation](../assets/demo.gif?raw=true)

Watches MPD for song change and takes action
  
### Features
- Gathers detailed song info
- Searches filesystem and online for cover art
- Caches covers to reduce web traffic
- Display song info and cover via [notify-send](https://gitlab.gnome.org/GNOME/libnotify)
- Change [cava](https://github.com/karlstav/cava) color based on cover art
- Display cover art on desktop with [feh](https://feh.finalrewind.org/)
  
### Requirements  
- zsh
- mpc
- curl
- jq
- imagemagick
- notify-send (optional)
- cava (optional)
- feh (optional)

### Installation  
Manual:  
```sh
git clone https://github.com/jeffmhubbard/mpnotd-zsh
sudo install -Dm 755 mpnotd-zsh/mpnotd.zsh /usr/local/bin/mpnotd
```
  
### Usage  
To start from terminal:  
  `mpnotd --time 20 -u low --cava -w cur.txt`  
  
```
-C, --config    specify path to config file
-p, --popup     enable notifications (defaults on)
-t, --time      time to display popup (in seconds)
-u, --urgency   urgency level (low, normal, critical)
-v, --cava      enable cava color
-c, --cover     enable cover mode
-c, --write     enable output file
-D, --debug     verbose output
-h, --help      print help
```
  
### Configuration  
```sh
# ~/.config/mpnotd/config

# number of days to cache cover art for
CACHE_DAYS=10

# set title of popup
POPUP_SUBJECT=" Now Playing"

# (if set) format popup body
POPUP_BODY="%title%\n%By %artist%\nFrom %album% (%date%)"

# time to display popup (seconds)
POPUP_DURATION=30

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
COVER_DURATION=10

# write current song info to file
WRITE_ENABLE=true

# (if set) key-value separator
WRITE_SEP="|"

```

### Notes
For floating cover art with i3
```ini
for_window [class="mpnotd"] floating enable
no_focus [class="mpnotd"]
```
