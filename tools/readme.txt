flac compression
apt install flac

flac --channel-map=none  --ignore-chunk-sizes /tmp/file.wav

Install Googe Earth

To install Google Earth on Debian 10, we need to install gdebi package on your Debian 10 system. If you have not installed gdebi package install it by running following command in terminal:

sudo apt install gdebi-core

Next, you need to download the Google Earth package by using or command. To download the package run following command:

wget https://dl.google.com/dl/earth/client/current/google-earth-pro-stable_current_amd64.deb

Now after downloading the package, you need to install the package using gdebi command to do so run following command:

sudo gdebi google-earth-pro-stable_current_amd64.deb
