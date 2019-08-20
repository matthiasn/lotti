
## Dependencies

    $ make deps

Alternatively, call these separately:

    $ make deps-npm
    $ make deps-pods
    $ make deps-link

Note that after running `deps-pods`, you need to modify the Pods project as described under **iOS TestFlight** below.


## Run JS Compiler

    $ shadow-cljs watch app


## Start metro bundler with more appropriate mem settings

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js start --reset-cache


## Creating Release Bundle on iOS

    $ shadow-cljs release app

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js bundle --entry-file app/index.js --platform ios --dev false --bundle-output ios/main.jsbundle --assets-dest ios


## Publishing to iOS TestFlight

You need to modify projects in **XCode** as follows for _Product > Archive_ to work:

- Add `Mailcore.framework` in `RNMailCore` target under _Libraries > RNMailCore.xcodeproj_
- Remove `React` target from `Pods` project


## Creating Release Bundle on Android
    
    $ make android
    $ adb install android/app/build/outputs/apk/release/app-release.apk


## Running on Android

    $ adb kill-server
    $ adb start-server
    $ adb devices

    $ react-native run-android