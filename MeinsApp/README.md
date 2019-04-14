
## Dependencies

    $ yarn
    $ react-native link realm


## Run JS Compiler

    $ shadow-cljs watch app


## Start metro bundler with more appropriate mem settings

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js start --reset-cache


## Creating Release Bundle

    $ node --expose-gc --max_old_space_size=4096 ./node_modules/react-native/local-cli/cli.js bundle --entry-file app/index.js --platform ios --dev false --bundle-output ios/main.jsbundle --assets-dest ios
