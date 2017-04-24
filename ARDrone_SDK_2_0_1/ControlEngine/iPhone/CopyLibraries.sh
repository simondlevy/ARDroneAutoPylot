#!/bin/sh

if [ ! -d ../../ARDroneLib ] ; then
    echo "../../ARDroneLib does not exist ! Checkout it with svn !"
    exit 1
fi

echo $PLATFORM_NAME $PLATFORM_PREFERRED_ARCH

if [ ${CONFIGURATION} = "Release" ] || [ ${CONFIGURATION} = "Distribution" ]; then
    export RELEASE_BUILD=yes
else
    export RELEASE_BUILD=no
fi

export PLATFORM_NAME_FORMAT=$PLATFORM_NAME CONFIGURATION_BUILD_DIR
export PLATFORM_NAME_FORMAT=`echo $PLATFORM_NAME_FORMAT | sed -e "s/iphone/iPhone/g"`
export PLATFORM_NAME_FORMAT=`echo $PLATFORM_NAME_FORMAT | sed -e "s/os/OS/g"`
export PLATFORM_NAME_FORMAT=`echo $PLATFORM_NAME_FORMAT | sed -e "s/simulator/Simulator/g"`

export PLATFORM_BUILD_FORMAT=$RELEASE_BUILD
export PLATFORM_BUILD_FORMAT=`echo $PLATFORM_BUILD_FORMAT | sed -e "s/yes/PROD_MODE/g"`
export PLATFORM_BUILD_FORMAT=`echo $PLATFORM_BUILD_FORMAT | sed -e "s/no/DEBUG_MODE/g"`

export PLATFORM_BIN_DIR_FORMAT=$PLATFORM_DEVELOPER_BIN_DIR
export PLATFORM_BIN_DIR_FORMAT=`echo $PLATFORM_BIN_DIR_FORMAT | sed -e "s/\///g"`

if [ ! -d $TARGET_BUILD_DIR ] ; then
    echo "Create "$TARGET_BUILD_DIR" directory."
    mkdir $TARGET_BUILD_DIR
fi

########################
#   Compiling FFMPEG   #
########################
if [ ! -e $TARGET_BUILD_DIR/libffmpeg.a ] ; then
    cd ../../ARDroneLib/FFMPEG
    if [ ${CURRENT_ARCH:0:4} = "armv" ]; then
        make RELEASE_BUILD=$RELEASE_BUILD iphone
        export FFMPEG_LIBRARY_PATH="../../ARDroneLib/Soft/Build/targets_versions/ffmpeg_iphone_"$PLATFORM_BUILD_FORMAT"_"$PLATFORM_NAME"_"$PLATFORM_BIN_DIR_FORMAT"llvm-gcc_4.2.1"
    else
        make RELEASE_BUILD=$(RELEASE_BUILD)
        export FFMPEG_LIBRARY_PATH="../../ARDroneLib/Soft/Build/targets_versions/ffmpeg_host_"$PLATFORM_BUILD_FORMAT"_"$PLATFORM_NAME"_"$PLATFORM_BIN_DIR_FORMAT"llvm-gcc_4.2.1"
    fi
    cp $FFMPEG_LIBRARY_PATH/lib*.a $TARGET_BUILD_DIR/
    cd -
fi

########################
# Copying ITTIAM libs  #
########################
export ITTIAM_LIBRARY_PATH="../../ARDroneLib/ITTIAM/avc_decoder/libs"
if [ -d $ITTIAM_LIBRARY_PATH ]; then
    cp $ITTIAM_LIBRARY_PATH/lib*.a $TARGET_BUILD_DIR/
fi
export ITTIAM_LIBRARY_PATH="../../ARDroneLib/ITTIAM/m4v_decoder/libs"
if [ -d $ITTIAM_LIBRARY_PATH ]; then
	cp $ITTIAM_LIBRARY_PATH/lib*.a $TARGET_BUILD_DIR/
fi

########################
# Compiling ARDroneLib #
########################
cd ../../ARDroneLib/Soft/Build
# Compiling
echo "Compiling ARDroneLib with options IPHONE_MODE = yes - RELEASE_BUILD = "$RELEASE_BUILD""
make IPHONE_MODE=yes RELEASE_BUILD=$RELEASE_BUILD

cd -

export ARDRONE_ARDRONELIB_PATH="../../ARDroneLib/Soft/Build/targets_versions/ardrone_lib_"$PLATFORM_BUILD_FORMAT"_vlib_"$PLATFORM_PREFERRED_ARCH"_"$PLATFORM_NAME"_"$PLATFORM_BIN_DIR_FORMAT"gcc_4.2.1"
export ARDRONE_SDKDEV_PATH="../../ARDroneLib/Soft/Build/targets_versions/sdk_"$PLATFORM_BUILD_FORMAT"_vlib_"$PLATFORM_PREFERRED_ARCH"_"$PLATFORM_NAME"_"$PLATFORM_BIN_DIR_FORMAT"gcc_4.2.1"
export ARDRONE_VLIB_PATH="../../ARDroneLib/Soft/Build/targets_versions/vlib_"$PLATFORM_BUILD_FORMAT"_"$PLATFORM_PREFERRED_ARCH"_"$PLATFORM_NAME"_"$PLATFORM_BIN_DIR_FORMAT"gcc_4.2.1"

cp $ARDRONE_ARDRONELIB_PATH/libpc_ardrone.a $TARGET_BUILD_DIR/libpc_ardrone.a
cp $ARDRONE_SDKDEV_PATH/libsdk.a $TARGET_BUILD_DIR/libsdk.a
cp $ARDRONE_VLIB_PATH/libvlib.a $TARGET_BUILD_DIR/libvlib.a

################################
# AUTOMATIC HEADERS GENERATION #
################################
echo "Generate files needed by ARDroneEngine."
rm -Rf Release/ARDroneGeneratedTypes.h
touch Release/ARDroneGeneratedTypes.h
echo "// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> Release/ARDroneGeneratedTypes.h
echo "// !!!! THIS FILE IS GENERATED AUTOMATICALLY, DO NOT CHANGE IT !!!!" >> Release/ARDroneGeneratedTypes.h
echo "// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> Release/ARDroneGeneratedTypes.h
echo "/*" >> Release/ARDroneGeneratedTypes.h
echo " *  ARDroneGeneratedTypes.h" >> Release/ARDroneGeneratedTypes.h
echo " *  ARDroneEngine" >> Release/ARDroneGeneratedTypes.h
echo " *" >> Release/ARDroneGeneratedTypes.h
echo " *  Automatically generated." >> Release/ARDroneGeneratedTypes.h
echo " *  Copyright 2010 Parrot SA. All rights reserved." >> Release/ARDroneGeneratedTypes.h
echo " *" >> Release/ARDroneGeneratedTypes.h
echo " */" >> Release/ARDroneGeneratedTypes.h
echo "#ifndef _ARDRONE_GENERATED_TYPES_H_" >> Release/ARDroneGeneratedTypes.h
echo "#define _ARDRONE_GENERATED_TYPES_H_" >> Release/ARDroneGeneratedTypes.h

echo ""  >> Release/ARDroneGeneratedTypes.h
grep -rh ^\#define ../../ARDroneLib/Soft/Common/navdata_common.h | grep NB_NAVDATA_DETECTION_RESULTS | sed 's/^\#define NB_NAVDATA_DETECTION_RESULTS \(.*\)/\#define ARDRONE_MAX_ENEMIES \1/g' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h

echo ""  >> Release/ARDroneGeneratedTypes.h
echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
grep -rh ^LED_ANIMATION\( ../../ARDroneLib/Soft/Common/led_animation.h | tr -d ' ' | tr -d '\t' | sed 's/^LED_ANIMATION(\([A-Za-z_0-9=]*\),\(.*\))/ARDRONE_LED_ANIMATION_\1,/g' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_LED_ANIMATION;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*ARDRONE_ANIM_" ../../ARDroneLib/Soft/Common/config.h | tr -d ' ' | tr -d '\t' | sed 's/^ARDRONE_ANIM_\([A-Za-z_0-9=,]*\)/ARDRONE_ANIMATION_\1/' | sed 's/^ARDRONE_ANIM_\([A-Za-z_0-9,]*\)/ARDRONE_ANIMATION_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_ANIMATION;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*CAD_TYPE_" ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's/^CAD_TYPE_\([A-Za-z_0-9=,]*\)/ARDRONE_CAMERA_DETECTION_\1/' | sed 's/^CAD_TYPE_\([A-Za-z_0-9,]*\)/ARDRONE_CAMERA_DETECTION_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_CAMERA_DETECTION_TYPE;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*ZAP_CHANNEL_" ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's/ZAP_CHANNEL_\([A-Za-z_0-9=,]*\)/ARDRONE_VIDEO_CHANNEL_\1/' | sed 's/ZAP_CHANNEL_\([A-Za-z_0-9,]*\)/ARDRONE_VIDEO_CHANNEL_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_VIDEO_CHANNEL;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*VBC_" ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's/VBC_\([A-Za-z_0-9=,]*\)/ARDRONE_VARIABLE_BITRATE_\1/' | sed 's/VBC_\([A-Za-z_0-9,]*\)/ARDRONE_VARIABLE_BITRATE_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_VARIABLE_BITRATE;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*ARDRONE_DETECTION_COLOR_" ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's/ARDRONE_DETECTION_COLOR_\([A-Za-z_0-9=,]*\)/ARDRONE_ENEMY_COLOR_\1/' | sed 's/ARDRONE_DETECTION_COLOR_\([A-Za-z_0-9,]*\)/ARDRONE_ENEMY_COLOR_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_ENEMY_COLOR;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh ^ARDRONE_CONFIG_KEY_ ../../ARDroneLib/Soft/Common/config_keys.h | tr -d ' ' | tr -d '\t' | tr '[:lower:]' '[:upper:]' | grep K_WRITE | grep -e CONTROL -e NETWORK -e VIDEO -e LEDS -e DETECT -e GPS -e USERBOX | sed 's/^ARDRONE_CONFIG_KEY_\([IMM|STR]*\)\(_A10\)*("\([A-Za-z_0-9=",]*\)",\([A-Za-z_0-9=]*\),INI_\([A-Za-z_0-9=]*\),\(.*\))/ARDRONE_CONFIG_KEY_\4,\/\/\5/g' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_CONFIG_KEYS;" >> Release/ARDroneGeneratedTypes.h

    echo "" >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh _CODEC.*\ *=\ *0x ../../ARDroneLib/VLIB/video_codec.h | tr -d ' ' | tr -d '\t' | sed 's/\([a-zA-Z0-9_]*\)_CODEC=0x\([0-9]*\).*/ARDRONE_VIDEO_CODEC_\1\ =\ 0x\2,/g' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_VIDEO_CODEC;" >> Release/ARDroneGeneratedTypes.h

    echo "" >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh FLYING_MODE_.*, ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's:FLYING_MODE_\(.*\),/.*:ARDRONE_FLYING_MODE_\1,:g' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_FLYING_MODE;" >> Release/ARDroneGeneratedTypes.h

    echo "" >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh ACADEMY_STATE_.* ../../ARDroneLib/Soft/Common/academy_common.h | grep -v typedef | tr -d ' ' | tr -d '\t' | sed 's:ACADEMY_STATE_\([a-zA-Z0-9_]*\).*:ARDRONE_ACADEMY_STATE_\1,:g' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_ACADEMY_STATE;" >> Release/ARDroneGeneratedTypes.h

    echo "" >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh ACADEMY_RESULT_.* ../../ARDroneLib/Soft/Common/academy_common.h | grep -v typedef | tr -d ' ' | tr -d '\t' | sed 's:ACADEMY_RESULT_\([a-zA-Z0-9]*\).*:ARDRONE_ACADEMY_RESULT_\1,:g' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_ACADEMY_RESULT;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "typedef enum {" >> Release/ARDroneGeneratedTypes.h
    grep -rh "\s*FLYING_STATE_" ../../ARDroneLib/Soft/Common/ardrone_api.h | tr -d ' ' | tr -d '\t' | sed 's/VBC_\([A-Za-z_0-9=,]*\)/ARDRONE_FLYING_STATE_\1/' | sed 's/FLYING_STATE_\([A-Za-z_0-9,]*\)/ARDRONE_FLYING_STATE_\1/' | sed 's/\/\*.*\*\///' >> Release/ARDroneGeneratedTypes.h
    echo "} ARDRONE_FLYING_STATE;" >> Release/ARDroneGeneratedTypes.h

    echo ""  >> Release/ARDroneGeneratedTypes.h
    echo "#endif // _ARDRONE_GENERATED_TYPES_H_" >> Release/ARDroneGeneratedTypes.h

    KEY_FILE=../../ARDroneLib/Soft/Common/config_keys.h
    TYPES_FILE=Release/ARDroneTypes.h
    OUT_FILE=Release/ARDroneGeneratedCommandIn.h

    TEMP_FILE=TEMPORARY

    rm -f $OUT_FILE
    rm -f $TEMP_FILE
    touch $OUT_FILE
    touch $TEMP_FILE

    grep -rh ^ARDRONE_CONFIG_KEY_ $KEY_FILE | grep K_WRITE | grep -e control -e network -e video -e leds -e detect -e gps -e userbox | tr ',' ' ' >> $TEMP_FILE
    awk '
BEGIN {
print "// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
print "// !!!! THIS FILE IS GENERATED AUTOMATICALLY, DO NOT CHANGE IT !!!!";
print "// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
print "/*";
print " *  ARDroneGeneratedCommandIn.h";
print " *  ARDroneEngine";
print " *";
print " *  Automatically generated.";
print " *  Copyright 2011 Parrot SA. All rights reserved";
print " *";
print " */";
print "";
print "#ifdef COMMAND_IN_CONFIG_KEY";
print "#ifdef COMMAND_IN_CONFIG_KEY_STRING";

INT_VAR="none"
UNS_VAR="none"
BOOL_VAR="none"
FLOAT_VAR="none"
DOUBLE_VAR="none"
}

/^\/\/[\ \t]*MATCH_TYPES\ :/ {
match ($0, /:\ .*\ :/);
VAR_NAME=substr($0, RSTART+2, RLENGTH-3);
if ($0 ~ /[\ \t]int32_t/) { INT_VAR=VAR_NAME }
if ($0 ~ /bool_t/) { BOOL_VAR=VAR_NAME }
if ($0 ~ /float32_t/) { FLOAT_VAR=VAR_NAME }
if ($0 ~ /float64_t/) { DOUBLE_VAR=VAR_NAME }
if ($0 ~ /uint32_t/) { UNS_VAR=VAR_NAME }
}

/^ARDRONE_CONFIG_KEY_/ {
CASE_NAME="ARDRONE_CONFIG_KEY_" toupper($2);
CONFIG_KEY=$2;
TYPE=$4;
ARG_TYPE=""
TYPE_PRINT=""
if (TYPE ~ /^int32_t/) { ARG_TYPE=INT_VAR; TYPE_PRINT="EQUAL" }
else if (TYPE ~ /bool_t/) { ARG_TYPE=BOOL_VAR; TYPE_PRINT="EQUAL" }
else if (TYPE ~ /float32_t/) { ARG_TYPE=FLOAT_VAR; TYPE_PRINT="EQUAL" }
else if (TYPE ~ /float64_t/) { ARG_TYPE=DOUBLE_VAR; TYPE_PRINT="EQUAL" }
else if (TYPE ~ /string_t/) { ARG_TYPE=STRING_VAR; TYPE_PRINT="STRCPY" }
else if (TYPE ~ /uint32_t/) { ARG_TYPE=UNS_VAR; TYPE_PRINT="EQUAL" }
if (TYPE_PRINT ~ /EQUAL/) { print "COMMAND_IN_CONFIG_KEY (" CASE_NAME ", " CONFIG_KEY ", " ARG_TYPE ")" }
else if (TYPE_PRINT ~ /STRCPY/) { print "COMMAND_IN_CONFIG_KEY_STRING (" CASE_NAME ", " CONFIG_KEY " )" }
}

END {
print "#endif //COMMAND_IN_CONFIG_KEY_STRING";
print "#endif //COMMAND_IN_CONFIG_KEY";
}
' $TYPES_FILE $TEMP_FILE >> $OUT_FILE

    rm -f $TEMP_FILE
