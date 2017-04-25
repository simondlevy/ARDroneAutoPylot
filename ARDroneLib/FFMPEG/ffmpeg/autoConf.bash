#!/bin/bash

# FUNCTIONS #

function build_target #TARGETNAME
{
    M_TARGET=$1

    HOSTNAME=$(uname -s)

    case $M_TARGET in
		iphone|iPhone|IPHONE|Iphone|IPhone)
			if [ "$HOSTNAME" = "Darwin" ]; then
				MY_CC="$PLATFORM_DEVELOPER_BIN_DIR/llvm-gcc --sysroot=$SDKROOT/ -L$SDKROOT/usr/lib/system/"
				MY_AR="$PLATFORM_DEVELOPER_BIN_DIR/ar"
				EXTRA_CFLAGS="-arch armv7 -mfpu=neon -miphoneos-version-min=6.0"
				EXTRA_LDFLAGS="-arch armv7 -isysroot $SDKROOT -miphoneos-version-min=6.0"
				COMMON_CONFIGURE_OPTIONS="--cc=\"$MY_CC\" --extra-cflags=\"$EXTRA_CFLAGS\" --extra-ldflags=\"$EXTRA_LDFLAGS\" --enable-cross-compile --target-os=darwin --sysroot=$SDKROOT/ $FFMPEG_STATIC"
				build_static_architecture armv7 " --cpu=cortex-a8 --arch=armv7 --enable-pic --enable-neon"
				make_static_binary_from armv7
			else
				echo "Can't build iPhone target while not on Mac-OS (Darwin)"
			fi
			;;
		android_no_neon)
			if [ -z $ANDROID_NDK_PATH ]; then
				echo "You must fill the ANDROID_NDK_PATH variable with the path to your Android NDK"
			else
				NDK_ROOT=$ANDROID_NDK_PATH
				MY_SYSROOT="$NDK_ROOT/platforms/android-8/arch-arm"
		MY_CC="$NDK_ROOT/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86/bin/arm-linux-androideabi-gcc --sysroot=$MY_SYSROOT"
		MY_AR="$NDK_ROOT/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86/bin/arm-linux-androideabi-ar"
		MY_CROSS_PREFIX="$NDK_ROOT/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86/bin/arm-linux-androideabi-"
		COMMON_CONFIGURE_OPTIONS="--cc=\"$MY_CC\" --enable-cross-compile --target_os=linux --sysroot=$MY_SYSROOT --cross_prefix=\"$MY_CROSS_PREFIX\" $FFMPEG_SHARED --nm=nm"
		build_shared_architecture armv7 " --arch=armv7 --cpu=cortex-a8 --enable-pic --disable-neon --enable-armvfp"
		build_shared_architecture armv6 " --arch=armv6 --cpu=arm1136j-s --disable-pic --disable-neon --enable-armvfp"
		make_shared_binary_from armv7
		make_shared_binary_from armv6
	    fi
	    ;;
	android_gtv)
		NDK_ROOT="/home/dbarysk/dev/sdk/android-ndk-r7c"
		MY_SYSROOT="$NDK_ROOT/toolchain/sysroot"
		MY_CC="$NDK_ROOT/toolchain/bin/arm-linux-androideabi-gcc --sysroot=$MY_SYSROOT"
		MY_AR="$NDK_ROOT/toolchain/bin/arm-linux-androideabi-ar"
		MY_CROSS_PREFIX="$NDK_ROOT/toolchain/bin/arm-linux-androideabi-"
				COMMON_CONFIGURE_OPTIONS="--cc=\"$MY_CC\" --enable-cross-compile --target_os=linux --sysroot=$MY_SYSROOT --cross_prefix=\"$MY_CROSS_PREFIX\" $FFMPEG_SHARED --nm=nm"
				build_shared_architecture armv7 " --arch=armv7 --cpu=cortex-a8 --enable-pic --disable-neon --enable-armvfp"
				make_shared_binary_from armv7
			;;
		host| \
			pc|PC|Pc| \
			Linux|linux|Ubuntu|Debian| \
			osx|os-x|OSX|OS-X|macos|MacOS)
			MY_CC="gcc"
			MY_AR="ar"
			COMMON_CONFIGURE_OPTIONS="--cc=\"$MY_CC\" --disable-yasm $FFMPEG_SHARED"
			HOSTARCH=$(uname -m)
			build_shared_architecture $HOSTARCH " --arch=$HOSTARCH"
			make_shared_binary_from $HOSTARCH
			;;
		hostStatic|host_static|static)
			MY_CC="gcc"
			MY_AR="ar"
			COMMON_CONFIGURE_OPTIONS="--cc=\"$MY_CC\" --disable-yasm $FFMPEG_STATIC"
			HOSTARCH=$(uname -m)
			build_static_architecture $HOSTARCH " --arch=$HOSTARCH"
			make_static_binary_from $HOSTARCH
			;;
		clean)
			ALL_DIRS=$TARGETS_DIR/ffmpeg_*
			rm -rf $ALL_DIRS
			make clean
			;;
		*)
			echo "Unknown target $M_TARGET"
			print_help
			;;
    esac
}

function build_static_architecture # ARCHNAME ARCH_FLAGS
{
    build_architecture "YES" $*
}

function build_shared_architecture # ARCHNAME ARCH_FLAGS
{
    build_architecture "NO" $*
}

function build_architecture # STATIC ARCHNAME ARCH_FLAGS
{
    STATIC="$1"
    ARCHNAME="$2"
    shift 2
    ARCH_FLAGS="$*"
    BUILD_FOLDER=$(arch_build_directory $ARCHNAME)

    check_date $STATIC $ARCHNAME
    if [ "$MUST_REBUILD" = "YES" ]; then
		echo "Building architecture $ARCHNAME <Output in $BUILD_FOLDER>"
		TMP_SCRIPT="$LOCAL_DIR/caller_$$_.sh"
#configure
		echo "#!/bin/sh" > $TMP_SCRIPT
		if [ "$BUILD_MODE" = "release" ]; then
			echo ./configure  --libdir="$BUILD_FOLDER" --shlibdir="$BUILD_FOLDER" --incdir="$INCLUDE_DIR" $COMMON_CONFIGURE_OPTIONS $FFMPEG_RELEASE $FFMPEG_CONFIG $ARCH_FLAGS >> $TMP_SCRIPT
		else
			echo ./configure  --libdir="$BUILD_FOLDER" --shlibdir="$BUILD_FOLDER" --incdir="$INCLUDE_DIR" $COMMON_CONFIGURE_OPTIONS $FFMPEG_DEBUG $FFMPEG_CONFIG $ARCH_FLAGS >> $TMP_SCRIPT
		fi
		echo "" >> $TMP_SCRIPT
		chmod +x $TMP_SCRIPT
		if [ -f /proc/cpuinfo ]; then
			JMOD=$(cat /proc/cpuinfo | grep processor | wc -l)
			$TMP_SCRIPT && cat config.h | sed 's:#define\ HAVE_INLINE_ASM\ 1:#define HAVE_INLINE_ASM 0:' > config.h.new && mv config.h.new config.h && make -j$JMOD && make install && make clean
		else
			$TMP_SCRIPT && cat config.h | sed 's:#define\ HAVE_INLINE_ASM\ 1:#define HAVE_INLINE_ASM 0:' > config.h.new && mv config.h.new config.h && make && make install && make clean
		fi
		rm $TMP_SCRIPT
    else
		echo "Architecture $ARCHNAME is already built"
    fi
}

function make_static_binary_from # ARCHS
{
    echo "Creating universal static lib file from architectures $*"
    make_binary_from "YES" $*
}

function make_shared_binary_from # ARCHS
{
    echo "Creating universal dynamic lib file from architectures $*"
    make_binary_from "NO" $*
}

function make_binary_from # STATIC ARCHS
{
    local GLOBAL_DIR=$(arch_build_directory $M_TARGET)
    if [ ! -d $GLOBAL_DIR ]; then
		mkdir $GLOBAL_DIR
    fi
    local STATIC=$1
    shift 1
    case $STATIC in
		YES)
			if [ -z $2 ]; then # Called with only one arch
				local BUILD_DIR=$(arch_build_directory $1)
				for lib in libavcodec.a libavdevice.a libavfilter.a libavformat.a libavutil.a libswscale.a ; do
					cp $BUILD_DIR/$lib $GLOBAL_DIR/$lib
				done
			else
				if [ "$HOSTNAME" = "Darwin" ]; then
					for lib in libavcodec.a libavdevice.a libavfilter.a libavformat.a libavutil.a libswscale.a; do
						COMMAND_LINE="lipo -create "
						for ARCH in $*; do
							local ARCH_DIR=$(arch_build_directory $ARCH)
							COMMAND_LINE="$COMMAND_LINE -arch $ARCH $ARCH_DIR/$lib"
						done
						COMMAND_LINE="$COMMAND_LINE -output $GLOBAL_DIR/$lib"
						$COMMAND_LINE
					done
				else
					echo "Don't know what to do on $HOSTNAME for 2 or more archs"
				fi
			fi
			;;
		NO)
			if [ "$HOSTNAME" = "Darwin" ]; then
				EXT=dylib
			else
				EXT=so
			fi
			if [ -z $2 ]; then # Called with only one arch
				local BUILD_DIR=$(arch_build_directory $1)
				cd $GLOBAL_DIR
		for lib in $(ls $BUILD_DIR | xargs) ; do 
		    if [ ! -h $BUILD_DIR/$lib ] && [ ! -d $BUILD_DIR/$lib ]; then 
						cp $BUILD_DIR/$lib ./
						if [ "$EXT" = "dylib" ]; then # dylib format is libxxxx.1.2.3.dylib
							ln -s $lib $(echo $lib | sed 's:\([a-z][a-z]*\)\(\.[0-9][0-9]*\)\..*\(\.dylib\):\1\3:') 2> /dev/null
							ln -s $lib $(echo $lib | sed 's:\([a-z][a-z]*\)\(\.[0-9][0-9]*\)\..*\(\.dylib\).:\1\2\3:') 2> /dev/null
						else # so format is libxxxx.so.1.2.3
							ln -s $lib $(echo $lib | sed 's:\([a-z][a-z]*\.so\)\(\.[0-9][0-9]*\)\..*:\1:') 2> /dev/null
							ln -s $lib $(echo $lib | sed 's:\([a-z][a-z]*\.so\)\(\.[0-9][0-9]*\)\..*:\1\2:') 2> /dev/null
						fi
					fi
				done
				cd - > /dev/null
			else
				if [ "$HOSTNAME" = "Darwin" ]; then
					for lib in libavcodec.$EXT libavdevice.$EXT libavfilter.$EXT libavformat.$EXT libavutil.$EXT libswscale.$EXT; do
						COMMAND_LINE="lipo -create "
						for ARCH in $*; do
							local ARCH_DIR=$(arch_build_directory $ARCH)
							COMMAND_LINE="$COMMAND_LINE -arch $ARCH $ARCH_DIR/""$lib"
						done
						COMMAND_LINE="$COMMAND_LINE -output $GLOBAL_DIR/""$lib"
						$COMMAND_LINE
					done
				else
					echo "Don't know what to do on $HOSTNAME for 2 or more archs"
				fi
			fi
			;;
		*)
			;;
    esac
}

function check_date # STATIC ARCH
{
    MUST_REBUILD="YES"
    LIBPATH=$(arch_build_directory $2)
    if [ "$1" = "YES" ]; then # Static
		EXT=a
    elif [ "$HOSTNAME" = "Darwin" ]; then # Dynamic on Mac/iPhone
		EXT=dylib
    else # Dynamic on Linux
		EXT=so
    fi
    for lib_name in libavcodec.$EXT libavdevice.$EXT libavfilter.$EXT libavformat.$EXT libavutil.$EXT libswscale.$EXT; do
		LIBNAME=$LIBPATH/$lib_name
		if [ -e $LIBNAME ]; then
			if [ "$HOSTNAME" = "Darwin" ]; then
				MY_DATE=$(stat -f %m $0)
				ARCH_DATE=$(stat -f %m $LIBNAME)
			else
				MY_DATE=$(stat --printf %Y $0)
				ARCH_DATE=$(stat --printf %Y $LIBNAME)
			fi
			if (( $ARCH_DATE < $MY_DATE )); then
				MUST_REBUILD="YES"
				break
			else
				MUST_REBUILD="NO"
			fi
		else
			MUST_REBUILD="YES"
			break
		fi
    done
	if [ ! -d $INCLUDE_DIR ]; then
		MUST_REBUILD="YES"
	fi
}

function print_help
{
    echo "To add a new target :"
    echo "Add case for your M_TARGET"
    echo " -> MY_CC holds your compiler [gcc]"
    echo " -> MY_AR holds your archiver [ar]"
    echo " -> COMMON_CONFIGURE_OPTIONS holds your 'architecture independant' options to configure PLUS your FFMPEG_SHARED/STATIC choice [--cc=\$MY_CC $FFMPEG_SHARED]"
    echo " -> Build an arch by setting both variables above, then call 'build_[static/shared]_architecture architecture \"arch_specific_flags\"'"
    echo " -> Compile all your binaries into one by calling 'make_[static/shared]_binary_from <architectures list>'"
}

function arch_build_directory # ARCH
{
    if [ "$M_TARGET" = "iphone" ]; then
		OS_VERSION="iphoneos"
    elif [ "$HOSTNAME" = "Darwin" ]; then
		OS_VERSION=$(uname -sr | sed -e "s/[ \/]/_/g")
    else
		OS_VERSION=$(uname -sor | sed -e "s/[ \/]/_/g")
    fi

   #Changed detection of GCC version as it was broken with newest gcc 4.6 by google                                                                                                                          
   GCC_VERSION=$($MY_CC -v 2>&1 | grep --color=never version | grep -v [Cc]onfigur | awk '{print $3}' | sed 's:\(.*\)\([0-9]\.[0-9]\.[0-9]\)\(\ .*\):\2:')
#    GCC_VERSION=$($MY_CC -v 2>&1 | grep --color=never version | grep -v [Cc]onfigur | sed 's:\(.*\)\([0-9]\.[0-9]\.[0-9]\)\(\ .*\):\2:')                                                                    
    GCC_DIR=$(which $MY_CC 2>&1 | sed 's:/::g')
    echo $TARGETS_DIR"/ffmpeg_"$1"_"$BUILD_NAME"_"$OS_VERSION"_"$GCC_DIR"_"$GCC_VERSION
}


# ACTUAL SCRIPT #

LOCAL_DIR=$(pwd)
if [ -z $ALL_TARGETS ]; then
    TARGETS_DIR=$LOCAL_DIR/../../Soft/Build/targets_versions/
else
    TARGETS_DIR=$ALL_TARGETS
fi
INCLUDE_DIR=$LOCAL_DIR/../Includes

rm -f $LOCAL_DIR/caller_*_.sh

export PATH=$PATH:$LOCAL_DIR

FFMPEG_CONFIG_GENERIC=" --disable-ffmpeg --disable-ffplay --disable-ffserver --disable-ffprobe --disable-doc --disable-everything"
FFMPEG_CONFIG_DECODER=" --enable-decoder=mpeg4 --enable-decoder=h264 --enable-decoder=rawvideo"
FFMPEG_CONFIG_ENCODER=" --enable-encoder=mpeg4 --enable-muxer=mp4 --enable-muxer=m4v --enable-muxer=rawvideo --enable-protocol=file"

FFMPEG_SHARED=" --disable-static --enable-shared"
FFMPEG_STATIC=" --disable-shared --enable-static"
FFMPEG_DEBUG=" --enable-debug --disable-stripping"
FFMPEG_RELEASE=" --disable-debug"


if [ -z $1 ]; then
    echo "You must specify a target"
    exit 0
elif [ -z $2 ]; then
    BUILD_MODE="release"
    BUILD_NAME="PROD_MODE"
    FFMPEG_CONFIG="$FFMPEG_CONFIG_GENERIC $FFMPEG_CONFIG_DECODER"
else
    BUILD_MODE=$2
    if [ "$BUILD_MODE" = "release" ]; then
		BUILD_NAME="PROD_MODE"
    elif [ "$BUILD_MODE" = "debug" ]; then
		BUILD_NAME="DEBUG_MODE"
    else
		echo "Invalid release option (must be release or debug)"
		exit 0
    fi
    if [ -z $3 ] || [ "$3" = "decoder" ]; then
        FFMPEG_CONFIG="$FFMPEG_CONFIG_GENERIC $FFMPEG_CONFIG_DECODER"
    elif [ "$3" = "encoder" ]; then
        FFMPEG_CONFIG="$FFMPEG_CONFIG_GENERIC $FFMPEG_CONFIG_ENCODER"
    elif [ "$3" = "both" ]; then
        FFMPEG_CONFIG="$FFMPEG_CONFIG_GENERIC $FFMPEG_CONFIG_DECODER $FFMPEG_CONFIG_ENCODER"
    else
        echo "Invalid ffmpeg option (valid are \"encoder\", \"decoder\" and \"both\")"
        exit 0
    fi
fi

build_target $1
