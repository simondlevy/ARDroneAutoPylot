1) Install Android SDK and NDK
------------------------------
- download Android SDK base package:
http://developer.android.com/sdk/index.html
- untar SDK in $HOME/dev/sdk (or any other location)
- export PATH=${PATH}:$HOME/android/android-sdk-linux_x86/tools
- apt-get install ant
- run 'android'
  * download SDK 2.2
- download Android NDK r5b package:
- untar NDK to $HOME/dev/sdk (or any other location)

2) Build application
--------------------
- Move to 'adfreeflight' app folder.
- Edit environment.properties and set paths to NDK and ARDroneLib.
- Update file local.properties with correct path to SDK.
- Run './build.sh release', './build.sh debug' or './build.sh clean' in order to make debug version, release version or clean.
- AdFreeFlight-release.apk or AdFreeFlight-debug.apk should appear under <project>/bin directory.

3) Install application on Android phone
---------------------------------------
  * connect phone via USB
  * adb install -r <project>/bin/AdFreeFlight-release.apk
