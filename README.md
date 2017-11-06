# meo

**meo** is a **personal information manager** for improving your life, past, present and future. It starts with a **geo-aware diary** or **log** where each entry captures your geo-location and whatever you want to note about that moment. You can use hashtags and mentions to better organize your information. You can also track your **tasks** and **habits**.


## Motivation

See [here](./doc/motivation.md)


## Components

**meo** consists of a **[Clojure](https://clojure.org/)** and **[ClojureScript](https://github.com/clojure/clojurescript)** system spanning the **browser** and a backend that runs on the **[JVM](https://en.wikipedia.org/wiki/Java_virtual_machine)**. This project lives in the **[iwaswhere-web](https://github.com/matthiasn/iWasWhere/tree/master/iwaswhere-web)** directory, which is also where you can find installation instructions and more information about the system's architecture.

There's also an **iOS app** that keeps track of visits and lets me quickly capture thoughts on the go. Currently, it's a very basic application written in **[Swift](https://swift.org/)**. It is not open sourced yet, but that will happen in due course. Ideally, by then it should also have been rewritten in **ClojureScript** and **[React Native](https://facebook.github.io/react-native/)**. Stay tuned.

This repository contains the **web application** part of **iWasWhere**. This system is written in **Clojure** and **ClojureScript**, making use of the **[systems-toolbox](https://github.com/matthiasn/systems-toolbox)** for its architecture.


## Installation

First, you need to compile the **ClojureScript**:

    $ lein cljsbuild once release

This will compile the ClojureScript into JavaScript using `:advanced` optimization.

The styling is maintained via **SASS** in a bunch of `.scss` files. For that, you first need to install the sass gem:

    $ sudo gem install sass

These need to be converted to CSS:
    
    $ lein sass

You can also have the CSS automatically recompiled when there are changes:

    $ sass --watch src/scss/iwaswhere.scss:resources/public/css/iwaswhere.css
    

There is no **CSS** framework involved here. Rather, the styling is self-contained, which is possible thanks to **[CSS Flexible Box Layout](https://www.w3.org/TR/css-flexbox-1/)**. It's great for layout. You should learn it.

You can also use the following task bundle instead of the previous two:

    $ lein build

There are also some JS dependencies to be assembled. For that, you need **[npm](https://www.npmjs.com/get-npm)**. 

Then you need to install webpack:

    $ npm install -g webpack

Then, install project dependencies with:

    $ npm install

Then, assemble them into a single file:

    $ cd bundle
    $ webpack -d --watch

    $ npm run build


## Usage

Once you have completed all the steps in the previous section, all you need to do is:

    $ lein run

This will run the application on **[http://localhost:8888/](http://localhost:8888/)**. By default, the webserver exposed by the systems-toolbox library listens on port 8888 and only binds to the localhost interface. You can use environment variables to change this behavior, for example:

    $ HOST="0.0.0.0" PORT=8888 lein run


## Development

During development, it makes sense to automatically recompile the **ClojureScript** when any change is detected. You can use **cljsbuild**, which works very well, but requires reloading the web page:

    $ lein cljsbuild auto release

Alternatively, you can use **[Figwheel](https://github.com/bhauman/lein-figwheel)** to automatically update the application as you make changes. For that, open another terminal:

    $ lein figwheel

The **systems-toolbox** library supports **Figwheel**, and all components will be reloaded while retaining their previous state. This works particularly well when doing changes that don't affect component state structure. Figwheel also detects CSS changes. Here, it particularly shines, as the UI will re-render immediately after any CSS change, without jumping or going back to the initial state after loading. For this, you need to keep the **sass watch** task running, like so:

    $ lein sass watch

Building the JS bundle:
    
    $ webpack -d --watch

## Tests

    $ lein test
    $ lein test2junit
    $ lein with-profile +test-reagent cljsbuild test


[![CircleCI Build Status](https://circleci.com/gh/matthiasn/iWasWhere.svg?&style=shield)](https://circleci.com/gh/matthiasn/iWasWhere)
[![TravisCI Build Status](https://travis-ci.org/matthiasn/iWasWhere.svg?branch=master)](https://travis-ci.org/matthiasn/iWasWhere)


## REPL

Inspecting the store component:

````
(use 'iww.jvm.core)
(require '[iww.jvm.file-utils :as fu])
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
