# Lotti

[![CodeFactor](https://www.codefactor.io/repository/github/matthiasn/lotti/badge)](https://www.codefactor.io/repository/github/matthiasn/lotti) [![Flutter Test](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml/badge.svg)](https://github.com/matthiasn/lotti/actions/workflows/flutter-test.yml)

Lotti helps you track habits, behavior, any data about yourself, in complete privacy.

![Habits Tab](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.312+1968/habits_screen.png)

Read more on [**Substack**](https://matthiasnehlsen.substack.com).

**New in 06/2023:** Lotti can now transcribe audio recordings in 99 languages using
[`whisper.cpp`](https://github.com/ggerganov/whisper.cpp).

## How to use Lotti
Check out the [MANUAL](https://github.com/matthiasn/lotti/blob/main/docs/MANUAL.md). The images in
there are updated automatically in CI using [`Fluttium`](https://fluttium.dev).

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
   else.

Lotti is a tool for improving life via establishing good habits and monitoring their outcome.
All collected data stays on your devices. Encrypted and entirely private synchronisation
between your devices can be set up (instructions will follow).

Lotti currently supports recording the following data types:

* Habits, which can be defined and tracked. Habit tracking then involves recording daily 
  completions, which can be successes, failures, and also skipping the completion in case a habit 
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


## Planned improvements:

* **Experiment/Intervention lifecycle.** The app is already useful for monitoring experiments or 
  interventions but those themselves currently remain implicit. For example, an experiment could be
  taking Vitamin D and see how that affects health parameters, or have a hypothesis what will happen,
  and then prove or disprove that, where a dashboard help monitor all relevant parameters. In 
  future versions, the lifecycle of interventions shall be made explicit, by defining them in 
  the first place, and then reviewing and refining them.
* Better **Reporting** how time is spent.
* **Upfront planning** of time budgets. 

Please check out [HISTORY.md](https://github.com/matthiasn/lotti/blob/main/docs/HISTORY.md) for all
the information on the project's history and back-story. You can find the previous version (written
in Clojure and ClojureScript) in this repo: [meins](https://github.com/matthiasn/meins).


## Principles

- Lotti is **private** and does not share any information with anyone - see the
  [Privacy Policy](https://github.com/matthiasn/lotti/blob/main/PRIVACY.md).
- Lotti is **open-source** and everyone is encouraged to contribute, be it via contributing to 
  code, providing feedback, testing, identifying bugs, etc.
- Lotti strives to be as **inclusive** as possible and any request for improved accessibility 
  will be addressed.
- Lotti is supposed to become a **friendly and welcoming community** of people who are 
  interested in data, improving their lives, and not or only very selectively sharing their data 
  in the process. Please head over to [Discussions](https://github.com/matthiasn/lotti/discussions) and say Hi.
- **Localization**. Lotti is multilingual and should be available in as many different languages as 
  possible. English is the primary language, and there are French, German, and Romanian translations. 
  Those need some update love, as the are many new UI labels that didn't exist when translations
  were last looked at. Please help, and also create [issues](https://github.com/matthiasn/lotti/issues)
  and PRs for languages you would like to see. Thanks!

## Beta testing

Lotti is currently available for beta testing for these platforms:

- **iOS** and **macOS** versions are available via a [Public Beta on TestFlight](https://testflight.apple.com/join/ZPgbDLGY).
  Development is primarily done on macOS and both the iOS and macOS versions are in constant use by
  the author. You can expect Lotti to work on these two platforms.
- The **Android** app is available as both `aab` and `apk` files on [GitHub Releases](https://github.com/matthiasn/lotti/releases).
  Both appeared to be working fine in some limited testing on both an Android phone and an Android
  tablet.
- **Windows** there's an installer named `lotti.msix` in [GitHub Releases](https://github.com/matthiasn/lotti/releases).
  That's not signed though. There's also a (currently hidden) release on the Microsoft Store which 
  appears to be working fine on Windows. However, some issues in the Microsoft Partner Center need
  to be resolved before making Lotti available on the Microsoft Store.
- **Linux**: the simplest way to release would be on the [Snap Store](https://snapcraft.io/snap-store),
  with automatic updates, but that's blocked by this [issue](https://github.com/matthiasn/lotti/issues/941).
  There's a file named `linux.x64.tar.gz` [GitHub Releases](https://github.com/matthiasn/lotti/releases)
  that contains the app. From limited testing, the app works fine on Linux, but is missing an app
  icon (could be a nice small PR).

## Install on Linux

```
$ sudo apt install pulseaudio-utils
```

### Building with Flatpak (Recommended for Distribution)

Lotti now includes complete Flatpak support for easy distribution and installation. The Flatpak configuration is located in the `flatpak/` directory.

**Quick Start with Build Script:**
```bash
cd flatpak
./flatpak_lotti_build.sh        # Automatically builds and runs Lotti
```

The script handles everything: prerequisites, Flutter build, bundle preparation, Flatpak build, and running the app.

**Manual Build:**
```bash
# Install prerequisites
sudo apt install flatpak flatpak-builder
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.freedesktop.Sdk//24.08 org.freedesktop.Platform//24.08

# Build the Flutter Linux release bundle
flutter build linux --release

# Create flutter-bundle directory with all necessary files
mkdir -p flatpak/flutter-bundle && cp -r build/linux/x64/release/bundle/. flatpak/flutter-bundle/

# Build Flatpak using the local manifest
flatpak-builder --repo=repo --force-clean build-dir flatpak/com.matthiasnehlsen.lotti.local.yml

# Test the app directly from build directory
flatpak-builder --run build-dir flatpak/com.matthiasnehlsen.lotti.local.yml /app/lotti
```

**For detailed instructions, see [flatpak/README.md](flatpak/README.md).**

The Flatpak includes:
- Proper desktop integration with icons
- Screenshot functionality support
- All necessary permissions for full functionality
- AppStream metadata for store distribution

### Traditional Build (Development)

For development and testing, you can build Lotti traditionally:

```
$ sudo apt-get install libsecret-1-dev libjsoncpp-dev libjsoncpp1 libsecret-1-0 sqlite3 libsqlite3-dev
$ flutter packages get
$ make build_runner
```

In case the network in the virtual machine is not connecting after resuming: `$ sudo dhclient ens33`

## Blog posts

- [Introducing Lotti or how I learned to love Flutter and Buildkite](https://matthiasnehlsen.com/blog/2022/05/05/introducing-lotti/)
- [How I switched to Flutter and lost 10 kilos](https://matthiasnehlsen.com/blog/2022/05/15/switched-to-flutter-lost-10-kilos/)

## Getting Started

1. Install Flutter, see [instructions](https://docs.flutter.dev/get-started/install).
2. Clone repository and go to `./lotti`
3. Run `flutter pub get`
4. Run `make watch` or `make build_runner` for code generation
5. Open in your favorite IDE, e.g. [Android Studio](https://developer.android.com/studio) 
6. Run, either from the IDE or using e.g. `flutter run -d macos`

### AI Chat Architecture (Overview)

The AI chat feature is structured for modularity and testability:

- `ChatSessionController` (UI state):
  - Manages chat state and streaming updates.
  - Caps streaming content (`maxStreamingContentSize = 1,000,000`) and adds an ellipsis when truncated.
  - Persists sessions via the repository and reverts model changes if persistence fails.

- `ChatRepository` (domain + integration):
  - Orchestrates sending messages, streams model deltas, accumulates tool-call deltas, runs tools, and streams a final response.
  - Uses `SystemMessageService` to build the system prompt and `ChatMessageProcessor` for testable logic.
  - In-memory session store (replaceable with durable storage).

- `ChatMessageProcessor` (pure, testable helpers):
  - Resolves AI configuration (provider + model) with cache (`configCacheDuration = 5 minutes`).
  - Converts conversation history, builds prompts, processes streaming frames and tool calls, and generates final responses.
  - Uses an injectable clock (`typedef Now = DateTime Function()`) for deterministic tests.

- `SystemMessageService` (prompt template):
  - Central place to compose the system prompt (includes today’s date and guidance for time ranges and tool usage).
  - Easy to extend for localization or per-category prompts.

Testing and Analyzer
- Tests focus on controllers, repository streaming, services, and processors (including edge cases).
- Analyzer must report zero warnings/infos before PR; test-only ignores are acceptable when justified.

## widgetbook

Lotti uses [widgetbook](https://pub.dev/packages/widgetbook) for developing and documenting widgets, for now only 
for select widgets. To run the widgetbook, run e.g. `fvm flutter run -d macos -t lib/widgetbook.dart`.

## Platform-specific setup

### Mac

Tested on `macOS 13.3`: no additional steps necessary. You only need to have Xcode installed.

### Linux

Tested on `Ubuntu 20.04.3 LTS` inside a virtual machine on VMWare Fusion In addition to the common
steps above, install missing dependencies:

```
$ sudo apt-get install libsecret-1-dev libjsoncpp-dev libjsoncpp1 libsecret-1-0 sqlite3 libsqlite3-dev
$ flutter packages get
$ make build_runner
``` 

In case the network in the virtual machine is not connecting after resuming: `$ sudo dhclient ens33`

### Windows

If your system is set up to run the Flutter counter example app, you should be good to go.

## Continuous Integration

This project uses [Buildkite](https://buildkite.com/docs/agent/v3/macos) on macOS for releasing to
TestFlight on iOS and macOS, and GitHub Actions for publishing to GitHub Releases for all other
platforms. 

## TODO

- **Audio Transcription Model Selection**: The audio transcription in `lib/features/ai_chat/services/audio_transcription_service.dart` needs improvements:
  - Allow users to select from available audio-capable models or configure a preferred model (currently defaults to 'gemini-2.5-flash')
  - ~~Support any audio-capable provider, not just Gemini~~ (Fixed: now supports any provider with audio-capable models)

## Contributions

Contributions to this project are very welcome. How can you help?

1. Please check under issues if there is anything specific that needs helping
   hands, or features to be discussed or implemented.
2. Improve the test coverage (currently at around 71%). Any additional tests are welcome,
   including code changes to make the code easier to test.
3. Create issues for feedback and ideas.
4. Help translate into more languages, and improve the existing translations.

Thanks!
