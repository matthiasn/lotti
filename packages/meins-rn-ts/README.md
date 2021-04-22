
<div align="center"><h1>Typescript React Native Starter</h1></div>
<br/>
<div align="center">A highly scalable foundation with a focus on best pratices and simplicity to start your React Native project in seconds.</div>
<br/>
<div align="center">
  <a href="https://david-dm.org/NewBieBR/typescript-react-native-starter">
    <img src="https://david-dm.org/NewBieBR/typescript-react-native-starter.svg" alt="Dependency Status" />
  </a>
  <a href="https://david-dm.org/NewBieBR/typescript-react-native-starter#info=devDependencies">
    <img src="https://david-dm.org/NewBieBR/typescript-react-native-starter/dev-status.svg" alt="devDependency Status" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" />
  </a>
  <a href="./CONTRIBUTING.md">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome" />
  </a>
</div>

## Quick Start

```bash
yarn global add trnc
```

```bash
trnc init <ProjectName>
```


## Features

- **Typescript**
  - [Typescript](https://github.com/microsoft/TypeScript) based: enhance code quality, understandability and scability with `Interface oriented development`

- **Flux State management**
  - [Redux](https://github.com/reduxjs/redux): predictable state container
  - [Redux Persist](https://github.com/rt2zz/redux-persist): offline and persistent store
  - [typesafe-actions](https://github.com/piotrwitek/typesafe-actions): create typesafe actions easily (and more)

      ```javascript
      import { createAction } from 'typesafe-actions';

      export const myAction = createAction('MY_ACTION', (payload) => payload)();
      ```

  - [Redux Saga](https://github.com/redux-saga/redux-saga): side effect model for Redux

- **Navigation**
  - [React Navigation](https://github.com/react-navigation/react-navigation): easy-to-use navigation solution based on Javascript

- **Unit testing**
  - Unit tests with [Jest](https://github.com/facebook/jest), [react-native-testing-library](https://github.com/callstack/react-native-testing-library) and [redux-saga-test-plan](https://github.com/jfairbank/redux-saga-test-plan)
- **Linting**
  - Eslint configured for React Native
  - VSCode Prettier compatible
  - Useful plugins installed (see  `.eslintrc.js`)

- **Internationalization and localization**
  - [react-i18next](https://github.com/i18next/react-i18next): easy to use package for i18n

- **Others**
  - Absolute import from `src`:
    Before:
    ```JSX
     import HomePage from '../../../../containers/HomePage'
    ```

    After:
    ```JSX
     import HomePage from 'src/containers/HomePage'
    ```
  - [react-native-normalize](https://github.com/NewBieBR/react-native-normalize): make your app responsive easily
  - [react-native-easy-icon](https://github.com/NewBieBR/react-native-easy-icon#readme): wrapper component of [react-native-vector-icons](https://github.com/oblador/react-native-vector-icons) for easier usage:
    Before:
    ```JSX
    import AntDesignIcon from 'react-native-vector-icons/AntDesign';

    <AntDesignIcon name="home" color="blue" size={42}/>

    ```

    After:
    ```JSX
    import Icon from 'react-native-easy-icon';

    <Icon type="antdesign" name="home" color="blue" size={42}/>
    ```

  - [Cocoapods](https://github.com/CocoaPods/CocoaPods): iOS dependencies manager
  - [jetifier](https://github.com/mikehardy/jetifier#readme): transition tool for [React Native 0.60 AndroidX migration](https://facebook.github.io/react-native/blog/2019/07/03/version-60#androidx-support)
  - Run linting pre-commit and unit testing pre-push with [husky](https://github.com/typicode/husky)'s hooks
  - Placeholder App Icon: useful for uploading your app to beta quickly with Fastlane
  - [App Icon generator](https://github.com/dwmkerr/app-icon#readme): generate all required sizes, label and annotate icon.
  - [Splash screen generator](https://github.com/zoontek/react-native-bootsplash): generate splash screen easily

## Project Structure

```
├── android
├── app.json
├── assets                               // All assets: images, videos, ...
├── credentials                          // Private informations: API keys,...
├── index.js
├── ios
├── publishing                           // Icon, screenshots, preview,... for App Store & Play Store
└── src
    ├── __tests__                        // Unit tests
    │   ├── App.test.tsx                 // App component's tests
    │   ├── components
    │   │   └── MyComponent.test.txs
    │   └── ...
    ├── App.tsx
    ├── actions                          // Actions
    │   ├── actionTypes.ts               // Action types
    │   └── app.ts                       // appReducer's actions
    ├── components                       // Components
    │   └── MyComponent.tsx
    ├── constants                        // Colors, sizes, routes,...
    │   └── strings.ts                   // i18n
    ├── containers                       // Screens, pages,...
    ├── lib                              // Libraries, services,...
    ├── index.tsx                        // Root component
    ├── reducers                         // Reducers
    │   └── app.ts                       // appReducer
    ├── sagas                            // Redux sagas
    ├── store.ts
    ├── types                            // Type declarations
    │   └── index.d.ts
    └── utils                            // Utilities
```

## Manual Installation

- Clone this repo

  ```
  git clone git@github.com:NewBieBR/typescript-react-native-starter.git <PROJECT_NAME>
  ```

  ```
  cd <PROJECT_NAME>
  ```

- Install dependencies
  ```
  yarn
  ```
- Rename the project

  ```
  yarn run rename <PROJECT_NAME>
  ```

- Migrate to AndroidX to [support React Native 0.60](https://facebook.github.io/react-native/blog/2019/07/03/version-60#androidx-support)

  ```
  yarn jetify
  ```

- Update pods

  ```
  cd ios && pod install
  ```

- Remove .git

  ```
  rm -rf .git
  ```

## Recommended configurations

- [Sentry](https://sentry.io/for/react-native/) for error tracking

- [Codepush](https://docs.microsoft.com/en-us/appcenter/distribution/codepush/) for Over-the-Air distributions

- [Fastlane](https://docs.fastlane.tools/) for deployment automations

## Useful Tips & Notes

### Apple Store Connect's missing compliance
This is added to your `Info.plist` in order to avoid Apple Store Connect's missing compliance warning.

```plist
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
So you don't have to *Provide Export Compliance Information* at **every push**,


<img src="https://i.stack.imgur.com/i7ret.png" height="100">

> Note that you might have to set that to `<true/>` if your [app uses encryption](https://developer.apple.com/documentation/bundleresources/information_property_list/itsappusesnonexemptencryption)


### Responsiveness with react-native-normalize

Use the **normalize** functio from react-native-normalize whenever you have to use a *hard value* (100, 200, 1000,...). This function will adapt your value accordingly to different screen sizes

### Without `normalize`

<img src="https://i.imgur.com/bLbnjsC.jpg" height="250"/>

### With `normalize`
<img src="https://i.imgur.com/4IqqAR2.jpg" height="250"/>



### Patch Package

When developing with React Native, sometimes I found bugs in the packages that I use so I fix them directly in the *node_modules/package-with-bug*. However, when I install a new package with *npm install*, the changes I made got override.

To prevent this, I use  [patch-package](https://github.com/ds300/patch-package) which allows me to modify and keep the changes I made.

> So no more waiting around for pull requests to be merged and published. No more forking repos just to fix that one tiny thing preventing your app from working.

Example:

```
# fix a bug in one of your dependencies
vim node_modules/some-package/brokenFile.js

# run patch-package to create a .patch file
npx patch-package some-package

# commit the patch file to share the fix with your team
git add patches/some-package+3.14.15.patch
git commit -m "fix brokenFile.js in some-package"
```


### Beta distribution with Fastlane
- Install [fastlane](https://docs.fastlane.tools/getting-started/ios/setup/)
  ```bash
  # Using RubyGems
  sudo gem install fastlane -NV

  # Alternatively using Homebrew
  brew cask install fastlane
  ```

> If you have issue installing or using fastlane on macos, check this solution: https://github.com/fastlane/fastlane/issues/15467#issuecomment-543093498

#### iOS
- Open your project Xcode workspace and update your app's `Bundle Identifier` and `Team`
- Initialize fastlane
  ```bash
  cd <PROJECT_NAME>/ios
  fastlane init
  ```
- Distribute your app
  ```bash
  fastlane beta
  ```

#### Android
- [Collect your Google Credentials](https://docs.fastlane.tools/getting-started/android/setup/#collect-your-google-credentials)
- Open your project with Android Studio and update your app's `applicationId` in `build.gradle (Module: app)` file
- Select `Generated Signed Bundle / APK...` from the `Build` menu
- `Next` then `Create new...` under `Key store path` then `Next` and `Finish`
- The first time you deploy your application, you MUST upload it into Google Play Console manually. Google don't allow to use theirs APIs for the first upload.
- Create your application in the [Google Play Console](https://play.google.com/apps/publish/) (unlike for iOS Fastlane cannot do that for you)
- Make sure that these 4 checkmark icons are green
    > Recommended order: `Pricing & distribution`, `Content rating`, `Store listing` and `App releases`

    > You can find the required assets for `Store listing` in the `publishing/android` folder


    <img src="https://i.stack.imgur.com/C7vDL.png" height="250"/>

- Initialize fastlane
  ```bash
  cd <PROJECT_NAME>/android
  fastlane init
  ```
- Use the Fastfile from `publishing`
  ```bash
  cp publishing/android/fastlane/Fastfile android/fastlane
  ```

- Distribute your app
  ```bash
  fastlane beta
  ```

    >  There is no official plugin to automatically upgrade android version code (unlike the iOS lane).
Before each deployment, be sure to manually upgrade the `versionCode` value inside `android/app/build.gradle`.

#### More
- Checkout the [Fastlane's beta distribution guide](https://github.com/thecodingmachine/react-native-boilerplate/blob/master/documentation/docs/3_Guides/BetaBuild.md) for more details
- [Fastlane's documentation](https://docs.fastlane.tools/getting-started/cross-platform/react-native/) for React Native
