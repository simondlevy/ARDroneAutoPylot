#!/bin/bash

source environment.properties

eval ARDRONE_LIB_PATH_FULL=$ARDRONE_LIB_PATH
eval ANDROID_NDK_PATH_FULL=$ANDROID_NDK_PATH
eval ANDROID_SDK_PATH_FULL=$ANDROID_SDK_PATH

echo JDK Path: $JDK_PATH
echo Android NDK Path: $ANDROID_NDK_PATH_FULL
echo Android SDK Path: $ANDROID_SDK_PATH_FULL
echo AR.Drone Library Path: $ARDRONE_LIB_PATH_FULL

./check_dependencies.sh

export JAVA_HOME=$JDK_PATH

ARDRONE_TARGET_OS="`uname`_`uname -r`_`uname -o`"
ARDRONE_TARGET_OS=$(echo $ARDRONE_TARGET_OS|sed 's#/#_#g')
echo $ARDRONE_TARGET_OS

GCC=$ANDROID_NDK_PATH/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86/bin/arm-linux-androideabi-gcc_4.6
GCC=$(echo $GCC|sed 's#/##g')

#if the target is "prod", then sign with the Parrot generic keystore
if [ "$1" = "prod" ]; then
    if [ ! -z "$ANDROID_KEYSTORE_PATH" ]; then
	if [ -d "$ANDROID_KEYSTORE_PATH" ]; then
	    TARGET=release
	    mv ./ant.properties ./ant.properties.bak
	    cp $ANDROID_KEYSTORE_PATH/ant.properties ./ant.properties
	else
	    echo "$ANDROID_KEYSTORE_PATH does not exist"
	    exit 0
	fi
    else
	echo "You must declare ANDROID_KEYSTORE_PATH to build for prod"
	exit 0
    fi
else
    TARGET=$1
fi

# Launch the build with ant tool
ant $TARGET -DARDRONE_TARGET_OS=$ARDRONE_TARGET_OS -DARDRONE_LIB_PATH=$ARDRONE_LIB_PATH_FULL -DANDROID_NDK_PATH=$ANDROID_NDK_PATH_FULL -Dsdk.dir=$ANDROID_SDK_PATH_FULL -Dbuild.packaging.debug=$TARGET -DGCC=$GCC

if [ "$1" = "prod" ]; then
    mv ./ant.properties.bak ./ant.properties
fi


