# meo

**meo** is a **personal information manager** for improving your life, past, present and future. It starts with a **geo-aware diary** or **log** where each entry captures your geo-location and whatever you want to note about that moment. You can use hashtags and mentions to better organize your information. You can also track your **tasks** and **habits**. Please get in touch when you require services around this tool, like customization or integration of additional data sources.

## Motivation

See [here](./doc/motivation.md)


## Components

**meo** consists of a **[Clojure](https://clojure.org/)** and **[ClojureScript](https://github.com/clojure/clojurescript)** system spanning an **Electron** application and a backend that runs on the **[JVM](https://en.wikipedia.org/wiki/Java_virtual_machine)**.

There's also an **iOS app** that keeps track of visits and lets me quickly capture thoughts on the go. Currently, it's a very basic application written in **[Swift](https://swift.org/)**. It is not open sourced yet, but that will happen in due course. Ideally, by then it should also have been rewritten in **ClojureScript** and **[React Native](https://facebook.github.io/react-native/)**. Stay tuned.

This repository contains the **web application** part of **meo**. This system is written in **Clojure** and **ClojureScript**, making use of the **[systems-toolbox](https://github.com/matthiasn/systems-toolbox)** for its architecture.


## Installation

There are two install scripts, one for Ubuntu and one for the Mac. These install the dependencies required. If anything is missing, please submit a pull request. And have a look at what the script for your platform does before blindly running it, and typing in your superuser password, which is required for `apt` in the Linux version.
 
 For Mac:

    $ ./install_mac.sh
     
For Linux: 
     
    $ ./install_ubuntu.sh

Then, you need to install the JavaScript dependencies:

    $ yarn install
 
Once that is done, you need to compile the ClojureScript code into JavaScript. These need to be run with the `cljs` profile. Using this profile keeps the size of the uberjar for the JVM-based backend smaller. I usually run one or more of these in different terminals or split views:

    $ lein with-profile cljs cljsbuild auto main
    $ lein with-profile cljs cljsbuild auto renderer-dev
    $ lein with-profile cljs cljsbuild auto updater

Alternatively, you can run these aliases (see project.clj);

    $ cljs-main-dev
    $ cljs-renderer-dev
    $ cljs-updater-dev

Next, you need to compile the SCSS files into CSS:

    $ lein sass4clj auto
 

## Usage

Once you have completed all the steps in the previous section, all you need to do is:

    $ lein run
    $ npm start
    

## Tests

    $ lein test

or

    $ lein test2junit


[![CircleCI Build Status](https://circleci.com/gh/matthiasn/meo.svg?&style=shield)](https://circleci.com/gh/matthiasn/meo)
[![TravisCI Build Status](https://travis-ci.org/matthiasn/meo.svg?branch=master)](https://travis-ci.org/matthiasn/meo)


## REPL

Inspecting the store component:

````
(use 'meo.jvm.core)
(require '[meo.jvm.file-utils :as fu])
(with-redefs [fu/data-path "data"] (restart! switchboard))
(def store (:cmp-state (:server/store-cmp (:components @(:cmp-state switchboard)))))
(def g (:graph @store))

(require '[ubergraph.core :as uber])
(uber/has-node? g :hashtags)

; find all hashtags
(def hashtags (map #(-> % :dest :tag) (uber/find-edges g {:src :hashtags})))

(pprint (sort (map clojure.string/lower-case hashtags)))
````

## License

Copyright © 2016-2017 **[Matthias Nehlsen](http://www.matthiasnehlsen.com)**. Distributed under the **GNU AFFERO PUBLIC LICENSE**, Version 3. See separate LICENSE file.
