# Lotti

[![CodeFactor](https://www.codefactor.io/repository/github/matthiasn/lotti/badge)](https://www.codefactor.io/repository/github/matthiasn/lotti) [![Flutter Test](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml/badge.svg)](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml)

Lotti is a smart journal that allows you to track relevant data about your life, entirely in private. What you deem relevant is up to you. Some ideas:

- Health-related data which can be imported automatically, such as steps, weight, sleep etc.
- Custom data types, such as the intake of water, food, alcohol, coffee, but also exercises such as pull-ups, you name (and define) it
- Time, as in defining tasks and then recording time spent on these tasks in the process
- Stories
- Tags
- People

Through the collection and monitoring of such data, Lotti allows you to monitor many different kinds of interventions, such as (but not limited to) health, weight, fitness etc. Ultimately, these aim at living a better life. Please share your success stories and ideas what can be improved.


## Planned improvements:

- Habit tracking. The previous Clojure-based version had simple habit tracking where habits could be checked off and monitored, such as daily flossing or whatever else you can imagine.
- Intervention lifecycle. The app is already useful for monitoring interventions but the interventions themselves currently remain implicit. In future versions, the lifecycle of interventions shall be made explicit, by defining them in the first place, and then reviewing and refining them.
- Reporting how time is spent
- Upfront planning of time budgets

Please check out **[HISTORY.md](./docs/HISTORY.md)** for information on the project's
history. You can find the previous version in the **[meins subdirectory](https://github.com/matthiasn/lotti/tree/main/meins)**.


## Principles

- Lotti is private and does not share any information with anyone - see the [Privacy Policy](./PRIVACY.md).
- Lotti is open-source and everyone is encouraged to contribute, be it via contributing to code, providing feedback etc.
- Lotti is inclusive and any request for improved accessibility will be addressed.
- Lotti is supposed to become a friendly and welcoming community of people who are interested in data, improving their lives, and not or only very selectively sharing their data in the process. Please head over to [Discussions](https://github.com/matthiasn/lotti/discussions) and say hi.


## Beta testing

Lotti is currently available for beta testing. The aim is to have pre-release versions available on [GitHub Releases](https://github.com/matthiasn/lotti/releases), specifically for Android, macOS, Linux and Windows. Currently, there are [build issues](https://github.com/matthiasn/lotti/labels/prerelease%20blocker) blocking the pre-release on some of the aforementioned platforms, please help!

Development is primarily done on macOS and both the **iOS** and **macOS** versions are available for beta testing via Apple's TestFlight. Please get in touch with the [author](https://github.com/matthiasn) if you are interesting in participating in the tests, the email address can be found in the profile. The aim is to get Lotti out on all app stores ASAP. More feedback will mean sooner general availability.


## Blog posts

- [Introducing Lotti or how I learned to love Flutter and Buildkite](https://matthiasnehlsen.com/blog/2022/05/05/introducing-lotti/)
- [How I switched to Flutter and lost 10 kilos](https://matthiasnehlsen.com/blog/2022/05/15/switched-to-flutter-lost-10-kilos/)


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


## Continuous Integration

This project uses Buildkite for releasing to TestFlight on iOS and macOS, 
plus publishing to GitHub releases. The following steps are necessary for 
setting up a new runner:

1) Install [Buildkite agent for macOS](https://buildkite.
   com/docs/agent/v3/macos)
2) Install [create-dmg](https://github.com/sindresorhus/create-dmg) for 
   bundling the DMG file for GitHub releases

HELP WANTED: Linux and Windows versions are not yet published on HitHub 
releases. Please consider helping out with the pipelines if you can.


## Contributions

Contributions to this project are very welcome. How can you help?

1. Please check under issues if there is anything specific that needs helping
   hands, or features to be discussed or implemented.
2. Now that the project is coming out of the initial prototyping stage, the test
   coverage needs to become much better. Any additional tests are welcome,
   including code changes to make the code easier to test.
3. For new feature ideas, please create an issue first and pitch the idea and
   we'll discuss.
   
