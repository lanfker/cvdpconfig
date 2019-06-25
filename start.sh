#!/bin/sh

chmod -R 755 /home/root/

## Quickly make sure the AP offered by CVDP accepts incoming connections
/etc/init.d/dnsmasq start 

### Set up CAN channel
cd /home/root
chmod +x can.sh
/home/root/can.sh

SMTPRC=/home/root/msmtprc
if [ -f "$SMTPRC" ]; then
	mv msmtprc /home/root/.msmtprc  && sync
fi

### Disable network manager...
NM_FILE=/etc/init.d/networkmanager
if [ -f "$NM_FILE" ]; then 
	mv /etc/init.d/networkmanager /etc/init.d/networkmanager.disabled  && sync
fi

### Disable NTP server
NTP_FILE=/etc/init.d/busybox-ntpd
if [ -f "$NTP_FILE" ]; then
	mv /etc/init.d/busybox-ntpd /etc/init.d/busybox-ntpd.disabled && sync
fi

### Disable the default HTTP service
HTTP_FILE=/etc/init.d/busybox-httpd
if [ -f "$HTTP_FILE" ]; then 
	mv /etc/init.d/busybox-httpd /etc/init.d/busybox-httpd.disabled && sync
fi

###  Run enhanced HTTP service written in Golang..
WEBCONF=/home/root/webconfig
if [ -f "$WEBCONF" ]; then 
	cd /home/root
	chmod +x webconfig
	./webconfig > /dev/null 2>&1 & 
	cd - 
fi

LIBCRYPTO=/usr/lib/libcrypto.so.1.0.2
if [ ! -f "$LIBCRYPTO" ]; then 
    cp /home/root/libcrypto.so.1.0.2 /usr/lib/ && sync
fi

READ_WIFI=true
WIFI_READER=/home/root/cvdp
if [[ "$READ_WIFI" = true && -f "$WIFI_READER" ]]; then
    TMP_WPACONFIG=/home/root/wpa_supplicant.conf
    if [ -f "$TMP_WPACONFIG" ]; then 
        rm /home/root/wpa_supplicant.conf
    fi
    ### Let the wifi reader handle SSID connection
    /home/root/cvdp

fi

if pgrep wpa_supplicant > /dev/null 2>&1 
then 
    echo "wpa_supplicant has been invoked by wifi reader" 
else
    ### Start Wi-Fi...
    echo "wifi reader failed, use default configuration instead"  
	/usr/sbin/wpa_supplicant -B -P /var/run/wpa_supplicant.wlan0.pid -i wlan0 -c /etc/wpa_supplicant.conf -D nl80211 
fi

dhclient wlan0 

### Make sure wlan0 has IPv4 address before proceed, this wait process only last for one minute.
### If one minute passed, but no IPv4 address on wlan0 is available, CVDP software's behavior is undefined.
x=0
while [ $(ifconfig  wlan0 |grep "inet a"| cut -f 2 -d ":" | cut -f 1 -d " ") = "" -a $x -le 60 ]
do
    x=$(( $x + 1 ))
    echo "wlan0 has no IP, waiting for system to obtain IP"
    sleep 1
done


### Set up LED indication...
cd /home/root
chmod +x toy.sh
/home/root/toy.sh > /dev/null 2>&1 & 

### Run Legacy HTTP service written in Python.
python /home/root/SimpleHTTPServer.py > /dev/null 2>&1 &
### Run NTP server program in Python. This is for time sync between CVDP and Image logging devices
python /home/root/ntp_server.py > /dev/null 2>&1 &

sleep 10

## RUN CVDP CODE FROM HERE.
CVDP_TMP=/home/root/CVDP-C.tmp
if [ -f "$CVDP_TMP" ]; then 
    cp $CVDP_TMP CVDP-C
    rm $CVDP_TMP
    sync
fi

cd /home/root
chmod +x CVDP-C

SD_CARD=/run/media/mmcblk1p1
if [ -d "$SD_CARD" ]; then 
	./CVDP-C -u >> /run/media/mmcblk1p1/cvdp_stderr.txt 2>&1 & 
else
	./CVDP-C -u >> /dev/null 2>&1 & 
fi
cd -

