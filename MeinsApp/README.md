
## Dependencies

    $ yarn
    $ react-native link realm
    $ react-native link rn-apple-healthkit
    $ react-native link react-native-camera
    $ react-native link @mapbox/react-native-mapbox-gl
    $ react-native link react-native-gesture-handler


## Run JS Compiler

    $ shadow-cljs watch app


## Start metro bundler with more appropriate mem settings

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js start --reset-cache


## Creating Release Bundle

    $ shadow-cljs release app

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js bundle --entry-file app/index.js --platform ios --dev false --bundle-output ios/main.jsbundle --assets-dest ios

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js bundle --platform android --dev false --entry-file app/index.js --bundle-output android/app/src/main/assets/index.android.bundle --assets-dest android/app/src/main/res/

    $ ./gradlew assembleRelease -x bundleReleaseJsAndAssets


## Running on Android

    $ adb kill-server
    $ adb start-server
    $ adb devices

    $ react-native run-android