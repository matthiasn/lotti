# Lotti

A smart journal.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view the
[Flutter online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Platform-specific setup
These purpose of these instructions is mainly to reproduce the dev environment quickly,
for the distribution or operating system versions named below. Please feel free to amend
missing steps or add a section for your favorite distribution and raise PRs for those.

Please make sure your Flutter environment generally works with a fresh starter app however
before raising issues that are related to your Flutter installation. Thanks!

### Linux
Tested on `Ubuntu 20.04.3 LTS` inside a virtual machine on VMWare Fusion:

1. Install Flutter manually, see [instructions](https://docs.flutter.dev/get-started/install/linux). Using `snapd` didn't appear to work.
2. Download and install [Android Studio](https://developer.android.com/studio)
3. Install missing dependencies:


```
$ sudo apt-get install libsecret-1-dev libjsoncpp-dev libjsoncpp1 libsecret-1-0 sqlite3 libsqlite3-dev
$ flutter packages get
$ make build_runner
``` 

In case the network in virtual machine not connecting after resuming: `$ sudo dhclient ens33`
