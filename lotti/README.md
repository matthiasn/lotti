# Lotti

A smart journal and a tool for living a better life by defining and monitoring
interventions.

## Getting Started

1. Install Flutter manually,
   see [instructions](https://docs.flutter.dev/get-started/install).
2. Download and install [Android Studio](https://developer.android.com/studio)
3. Clone repository and go to `./lotti`
4. Run `flutter pub get`
5. Run `flutter create`
6. Open `./lotti` in **Android Studio**

## Platform-specific setup

These purpose of these instructions is mainly to reproduce the dev environment
quickly, for the distribution or operating system versions named below. Please
feel free to amend missing steps or add a section for your favorite distribution
and raise PRs for those.

Please make sure your Flutter environment generally works with a fresh starter
app however before raising issues that are related to your Flutter installation.
Thanks!

### Mac

Tested on `macOS 12.3`: no additional steps necessary. You only need to have 
Xcode installed.

### Linux

Tested on `Ubuntu 20.04.3 LTS` inside a virtual machine on VMWare Fusion:

1. In addition to the common steps above, install missing dependencies:

```
$ sudo apt-get install libsecret-1-dev libjsoncpp-dev libjsoncpp1 libsecret-1-0 sqlite3 libsqlite3-dev
$ flutter packages get
$ make build_runner
``` 

In case the network in virtual machine not connecting after
resuming: `$ sudo dhclient ens33`

### Windows

Please create a PR with instructions for Windows if you find anything that is
required.

## Contributions

Contributions to this project are very welcome. How can you help?

1. Please check under issues if there is anything specific that needs helping
   hands, or features to be discussed or implemented.
2. Now that the project is coming out of the initial prototyping stage, the test
   coverage needs to become much better. Any additional tests are welcome,
   including code changes to make the code easier to test.
3. For new feature ideas, please create an issue first and pitch the idea and
   we'll discuss.
   