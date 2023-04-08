# Lotti

[![CodeFactor](https://www.codefactor.io/repository/github/matthiasn/lotti/badge)](https://www.codefactor.io/repository/github/matthiasn/lotti) [![Flutter Test](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml/badge.svg)](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml)

Read more on **Substack**:

- [#1: Why I'm building Lotti - an open-source self-improvement app](https://matthiasnehlsen.substack.com/p/why-im-building-lotti-an-open-source)
- [#2: Tracking Habits in Lotti](https://matthiasnehlsen.substack.com/p/tracking-habits-in-lotti)
- [#3: How to Track Habits in Lotti - A brief manual, Part I](https://matthiasnehlsen.substack.com/p/how-to-track-habits-in-lotti)
- [#4: How to Track Habits in Lotti - A brief manual - Part II](https://matthiasnehlsen.substack.com/p/how-to-track-habits-in-lotti-6f3)
- [#5: How to monitor habits - A brief manual, Part III](https://matthiasnehlsen.substack.com/p/5-how-to-monitor-habits)
- [#6: Development Update](https://matthiasnehlsen.substack.com/p/6-development-update)

## Core beliefs / the WHY

Lotti is a tool for self-improvement centered around these core beliefs:

1. Long-term outcomes in life can be improved by following good routines and establishing good 
   habits, such as healthy sleep, mindfulness and improved self-awareness, healthy eating, 
   enough physical activity and the like. Technology is essential when trying to establish and 
   monitor good habits. Paper-based checklists are undesirable.
2. Habits need to be monitored long-term. The 21-day habit theory, stating that it takes three 
   weeks to form a new habit and then subsequently sticking with it automatically is 
   questionable at best, and the only way to ensure that habits identified as important are 
   actually followed is to monitor them.
3. Any comprehensive attempt at tracking and monitoring the aforementioned areas of life 
   will result in collecting far more data than anyone should be willing to share with anyone 
   else, especially not a startup.

Lotti is a tool for improving life via establishing good habits and monitoring their outcome, 
without having to give up any information. All collected data stays on your devices, with 
encrypted and entirely private synchronisation between your devices.

Lotti currently supports recording the following data types:

* Habits, which can be defined and tracked. Habit tracking then involves recording daily 
  completions, which can successes, failures, and also skipping the completion in case a habit 
  could not be completed due to external circumstances.
* Health-related data which can be imported automatically, such as steps, weight, sleep, blood 
  pressure, resting heart rate, and whatever else can be recorded in Apple Health (or the 
  Android equivalent).
* Custom data types, such as the intake of water, food, alcohol, coffee, but also exercises such 
  as pull-ups, you name (and define) it.
* Text journal entries.
* Tasks, with different statuses to track their lifecycle: open, groomed, in progress, blocked, 
  on hold, done, rejected.
* Audio recordings, as spoken journal entries, and also audio notes, for example when working on 
  a task and documenting progress and doing a quick brain dump that can be useful when picking 
  up a task again later.
* Time, as in recording time spent on a tasks, and also a related story.
* Tags for better organization and discoverability of journal entries.
* Stories, a special tag type that is useful for reporting time spent on tasks related to their 
  respective stories.
* People, a special tag type with no additional functionality yet, only a different tag color.

Example from [blog](https://matthiasnehlsen.com/blog/2022/05/15/switched-to-flutter-lost-10-kilos/):

![screenshot of dashboard](https://matthiasnehlsen.com/static/37e205eaf8dd59b7d040395a051204b7/a911b/2022-05-14_charts.jpg "user configured dashboard")


## Planned improvements:

* **Intervention lifecycle.** The app is already useful for monitoring interventions but the 
  interventions themselves currently remain implicit, insofar as I can imagine and invent such 
  interventions in my mind and then build a dashboard for tracking success and failure. In 
  future versions, the lifecycle of interventions shall be made explicit, by defining them in 
  the first place, and then reviewing and refining them.
* Better **Reporting** how time is spent.
* **Upfront planning** of time budgets. 

Please check out [HISTORY.md](https://github.com/matthiasn/lotti/blob/main/docs/HISTORY.md) for 
all the information on the project's history and back-story. You can find the previous version 
in the [meins subdirectory](https://github.com/matthiasn/lotti/tree/main/meins).


## Principles

- Lotti is **private** and does not share any information with anyone - see the [Privacy Policy]
  (https://github.com/matthiasn/lotti/blob/main/PRIVACY.md).
- Lotti is **open-source** and everyone is encouraged to contribute, be it via contributing to 
  code, providing feedback, testing, identifying bugs, etc.
- Lotti strives to be as **inclusive** as possible and any request for improved accessibility 
  will be addressed.
- Lotti is supposed to become a **friendly and welcoming community** of people who are 
  interested in data, improving their lives, and not or only very selectively sharing their data 
  in the process. Please head over to [Discussions](https://github.
  com/matthiasn/lotti/discussions) and say Hi.
- **Localization**. Lotti aims to be multilingual and to be available in as many different 
  languages as possible. Currently, that is English and German, with [French](https://github.
  com/matthiasn/lotti/issues/936) in progress. Please create [issues](https://github.
  com/matthiasn/lotti/issues) for languages you would like to see.

## Beta testing

Lotti is currently available for beta testing. The aim is to have pre-release versions available 
on [GitHub Releases](https://github.com/matthiasn/lotti/releases). Currently, there are 
[build issues](https://github.com/matthiasn/lotti/labels/prerelease%20blocker) blocking the 
pre-release on some of the aforementioned platforms and help would be much appreciated.

Development is primarily done on macOS and both the iOS and macOS versions are available for 
beta testing via Apple's TestFlight. Please get in touch with the [author](https://github.com/matthiasn) if you are interested in participating in the tests, the email address can be 
found in the profile. The aim is to get Lotti out on all app stores in 2023.


## Blog posts

- [Introducing Lotti or how I learned to love Flutter and Buildkite](https://matthiasnehlsen.com/blog/2022/05/05/introducing-lotti/)
- [How I switched to Flutter and lost 10 kilos](https://matthiasnehlsen.com/blog/2022/05/15/switched-to-flutter-lost-10-kilos/)


## Getting Started

1. Install Flutter manually,
   see [instructions](https://docs.flutter.dev/get-started/install).
2. Download and install [Android Studio](https://developer.android.com/studio)
3. Clone repository and go to `./lotti`
4. Run `flutter pub get`
5. Run `make watch` or `make build_runner` for code generation
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

HELP WANTED: The Windows version is not yet published on GitHub releases. On Linux, a snap 
release could be helpful. Help needed.


## Contributions

Contributions to this project are very welcome. How can you help?

1. Please check under issues if there is anything specific that needs helping
   hands, or features to be discussed or implemented.
2. Now that the project is coming out of the initial prototyping stage, the test
   coverage needs to become much better. Any additional tests are welcome,
   including code changes to make the code easier to test.
3. For new feature ideas, please create an issue first and pitch the idea and
   we'll discuss.
   
