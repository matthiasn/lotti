(ns ^:figwheel-no-load env.ios.main
  (:require [reagent.core :as r]
            [re-frame.core :refer [clear-subscription-cache!]]
            [meo.ios.core :as core]
            [figwheel.client :as fw]
            [env.config :as conf]
            [meo.ui :as ui]))

(enable-console-print!)

(def cnt (r/atom 0))
(defn reloader [] @cnt [ui/app-root])

;; Do not delete, root-el is used by the figwheel-bridge.js
(def root-el (r/as-element [reloader]))

(defn force-reload! []
  (clear-subscription-cache!)
  (swap! cnt inc)
  )

(fw/start {
           :websocket-url    (:ios conf/figwheel-urls)
           :heads-up-display false
           :jsload-callback  force-reload!})

(core/init)
