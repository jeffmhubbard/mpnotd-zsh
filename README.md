# mpnotd-zsh  
MPD Notification Daemon (ZSH)  
  
Watches MPD for song change and displays notifications.  
  
* Display current song information
* Fetch cover art
* Change CAVA fg color based on cover art
  
### Requirements  
zsh  
mpc  
libnotify  
curl  
jq  
sed  
imagemagick  
cava  
  
### Installation  
  
Manual:  
```sh
git clone https://github.com/jeffmhubbard/mpnotd-zsh
cd mpnotd-zsh
sudo install -Dm 755 mpnotd.zsh /usr/local/bin/mpnotd.zsh
```
  
### Usage  
To start from terminal or application launcher:  
  `mpnotd.zsh --time 20 -u low --cava`  
  
| Arg | |
| :- | :- |
| --config | specify path to config file
| -t, --time | time to display popup (in seconds)
| -u, --urgency | string | urgency level (low, normal, critical)
| -c, --cava | enable cava color
| -h, --help | print help
  
### Configuration  
  
```sh
# mpnotd config

# set title of popup
POPUP_TITLE=" Now Playing"

# time to display popup (seconds)
POPUP_TIME=30

# popup urgency (low, normal, critical)
POPUP_LEVEL=low

# change CAVA fg color based on cover art
CAVA_ENABLED=true

# path to CAVA config
CAVA_CFG="$HOME/.config/cava/config"

# palette to use instead of dominant color
CAVA_COLORS=(fc391f 31e722 eaec23 5833ff f935f8 14f0f0)

```
