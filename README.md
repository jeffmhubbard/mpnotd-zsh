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
  
### Arguments  
*  --config             path to alternate config file  
*  -t or --time         time to display popup (in seconds)
*  -u or --urgency      urgency level (low, normal, critical)
*  -c or --cava         enable cava color
*  -h or --help         print help  
  
### Configuration  
  
```sd
# mpnotd config

# set title of popup
POPUP_TITLE=" Now Playing"
# time to display popup (seconds)
POPUP_TIME=30
# popup urgency (low, normal, critical)
POPUP_TYPE=low

# change CAVA fg color based on cover art
CAVA_ENABLED=true
# path to CAVA config
CAVA_CFG="$HOME/.config/cava/config"

```
