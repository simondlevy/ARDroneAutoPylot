#!/bin/bash

# As android can't use the .so.xx version of libs, we must change the SONAME
# of our libs to use the .so file

if [ -z $(which rpl) ]; then
    echo "You must install rpl (sudo apt-get install rpl) before running this script"
    exit 1
fi

cd $1 
rpl -x.so -e libavcodec.so.53 "libavcodec.so\0\0\0" *
rpl -x.so -e libavdevice.so.53 "libavdevice.so\0\0\0" *
rpl -x.so -e libavfilter.so.2 "libavfilter.so\0\0" *
rpl -x.so -e libavformat.so.53 "libavformat.so\0\0\0" *
rpl -x.so -e libavutil.so.51 "libavutil.so\0\0\0" *
rpl -x.so -e libswscale.so.2 "libswscale.so\0\0" *
 
