(ns meins.util.bg-geolocation
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :as shared]
            ["react-native-background-geolocation" :as rn-bg-geo]))

(def BackgroundGeolocation (aget rn-bg-geo "default"))

(def cfg
  (clj->js
    {:reset           true
     :desiredAccuracy (.-DESIRED_ACCURACY_HIGH BackgroundGeolocation)
     :distanceFilter  10
     :stopTimeout     1
     :debug           true
     :logLevel        (.-LOG_LEVEL_VERBOSE BackgroundGeolocation)
     :stopOnTerminate false
     :startOnBoot     true
     :batchSync       false
     :autoSync        false}))

(defn start-bg-location []
  (try
    (let [on-location (fn [loc] (js/console.warn "location" loc))
          on-motion (fn [m] (js/console.warn "motion" m))
          on-activity (fn [act] (js/console.warn "activity" act))
          on-error (fn [err] (js/console.error err))
          on-ready (fn [state]
                     (js/console.warn "ready" state)
                     (.start BackgroundGeolocation
                             (fn [] (js/console.warn "started-watching"))))]
      (.onLocation BackgroundGeolocation on-location on-error)
      (.onActivityChange BackgroundGeolocation on-activity)
      (.onMotionChange BackgroundGeolocation on-motion)
      (.ready BackgroundGeolocation cfg on-ready))
    (catch :default e (shared/alert (str "geolocation not available: " e)))))
