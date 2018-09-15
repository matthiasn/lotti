(ns ^:figwheel-no-load env.android.main
  (:require [reagent.core :as r]
            [re-frame.core :refer [clear-subscription-cache!]]
            [meo.android.core :as core]
            [figwheel.client :as fw]
            [env.config :as conf]))

(enable-console-print!)

(assert (exists? core/init) "Fatal Error - Your core.cljs file doesn't define an 'init' function!!! - Perhaps there was a compilation failure?")
(assert (exists? core/app-root) "Fatal Error - Your core.cljs file doesn't define an 'app-root' function!!! - Perhaps there was a compilation failure?")

(def cnt (r/atom 0))
(defn reloader [] @cnt [core/app-root])

;; Do not delete, root-el is used by the figwheel-bridge.js
(def root-el (r/as-element [reloader]))

(defn force-reload! []
      (clear-subscription-cache!)
      (swap! cnt inc))

(fw/start {
           :websocket-url    (:android conf/figwheel-urls)
           :heads-up-display false
           :jsload-callback  force-reload!})

(core/init)
