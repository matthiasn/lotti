# meins

The **open-source** application **meins** is an experimentation toolkit for **designing your life**. It helps you collect relevant information,  design, and then implement change. Most importantly, it does so without leaking data, because everything stays within your realm of control, and you can always verify this claim in the [source code](https://github.com/matthiasn/meins/tree/master/src). Please have a look at the [manual](https://github.com/matthiasn/meins/blob/master/doc/manual.md) to find out more about what it does. The same text is available in the application under the help menu. 

Here's how that currently looks like:

![screenshot](http://matthiasnehlsen.com/images/2018-03-08-meo-charts.png)


# Installers

You can download a **beta version** of the application for Linux, Mac, and Windows on [GitHub](https://github.com/matthiasn/meins/releases), where you want the highest existing version for your platform. The Mac version is usually the newest, and the others can lag. You only have to download the binary once, as there are automatic updates. You can also build the application yourself, with a simple [make](https://www.gnu.org/software/make) command, plus an unknowable amount of time for getting your development environment right.

All of these provide auto-update functionality, which can be accessed through "Check for Updates" in the application menu. In addition, checks for a newer version run once every 24 hours.


## Motivation

See this [blog post](http://matthiasnehlsen.com/blog/2018/03/15/introducing-meo/) for the background. Back then it was called **meo**, but has since been renamed to **meins**.


## Components

**meins** consists of a **[Clojure](https://clojure.org/)** and **[ClojureScript](https://github.com/clojure/clojurescript)** system spanning an **Electron** application and a backend that runs on the **[JVM](https://en.wikipedia.org/wiki/Java_virtual_machine)**. There's also a **mobile companion app** written in **ClojureScript** on top of **[React Native](https://facebook.github.io/react-native/)**, see `./rn-app` in this repository. 

All subsystems in meins make use of the **[systems-toolbox](https://github.com/matthiasn/systems-toolbox)** for their architecture.

Here's how the app currently looks like:

![screenshot](http://matthiasnehlsen.com/images/2018-03-08-mobile.png)


## Installation

There is a `Makefile` that contains all the build targets. You will obviously need **[GNU make](https://www.gnu.org/software/make/)** to run the targets. Alternatively, you can run the commands in there individually. Please have a look at the `Makefile` to see what the commands are.

To prepare your environment and install the required dependencies on a Mac, you can run

    $ make install-mac
    
For Ubuntu, run

    $ make install-ubuntu
    
If anything is missing or redundant, please submit a pull request, I am not running these often. **[Leiningen](https://leiningen.org/)** itself is missing, not sure how to best install that from here. Maybe it's best to just use the commands in the install targets as a template for what you need to install. Please have a look at what the target for your platform does before blindly running it.

Once all the dependencies installed already, you can create a packaged version of **meins** running

    $ make package 

This will download dependencies, both Clojure and **[npm](https://www.npmjs.com/)**, and then run tests, build, and package the entire application for the platform you are running on. This will take The backend of the application is a standalone uberjar that runs with a packaged custom Java runtime that is generated when building meins using **[jlink](https://openjdk.java.net/jeps/282)**. The resulting runtime is only a fraction of the size of a JDK. Packaging the runtime is more reliable than trying to rely on a recent JRE on a non-developer machine. This packaging mechanism is provided by [Project Jigsaw](https://openjdk.java.net/projects/jigsaw/quick-start),

## Development

For development, you need to install the JavaScript dependencies:

    $ yarn install
 
Once that is done, you need to compile the ClojureScript code into JavaScript. These need to be run with the `cljs` profile. Using this profile keeps the size of the uberjar for the JVM-based backend smaller.

    $ lein cljs-main
    $ lein cljs-figwheel

The `cljs-figwheel` task needs to be running in separate terminals, as it keeps running and watches the file system for changes. Next, you need to compile the SCSS files into CSS:

    $ lein sass4clj auto

Once you have completed all the steps in the previous section, all you need to do is the following, once again in separate terminals:

    $ lein run
    $ npm start

Now you should have an environment running where any change in the code (including the SCSS) reloads the content of the Electron application.

## Packaging

**meins** is released as follows:

    $ ./make release

This will package and sign the application, for the platform it runs on. Then, it will upload the resulting package(s) to the releases section on the project page. Note that the proper `GH_TOKEN` environment variable must be set for this.


## Tests

    $ lein test

or

    $ lein test2junit


[![CircleCI Build Status](https://circleci.com/gh/matthiasn/meins.svg?&style=shield)](https://circleci.com/gh/matthiasn/meo)
[![TravisCI Build Status](https://travis-ci.org/matthiasn/meins.svg?branch=master)](https://travis-ci.org/matthiasn/meo)


## How to help

Contributions and pull requests are **very welcome**. Please check the open issues for where help is required the most, and file issues for anything else that you find.


## License

Copyright © 2016-2019 **[Matthias Nehlsen](http://www.matthiasnehlsen.com)**. Distributed under the **GNU AFFERO PUBLIC LICENSE**, Version 3. See separate LICENSE file.
