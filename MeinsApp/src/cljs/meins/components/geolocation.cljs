(ns meins.components.geolocation
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :as shared]
            ["intl" :as intl]
            [cljs-bean.core :refer [bean ->clj ->js]]
            ["react-native-background-geolocation" :as rn-bg-geo]
            [meins.helpers :as h]))

(def BackgroundGeolocation (aget rn-bg-geo "default"))

(def cfg
  (clj->js
    {:reset           true
     :desiredAccuracy (.-DESIRED_ACCURACY_HIGH BackgroundGeolocation)
     :distanceFilter  10
     :stopTimeout     1
     :debug           false
     :logLevel        (.-LOG_LEVEL_VERBOSE BackgroundGeolocation)
     :stopOnTerminate false
     :startOnBoot     true
     :batchSync       false
     :autoSync        false}))

(defn state-fn [put-fn]
  (try
    (let [state (atom {})
          on-location (fn [loc]
                        (let [loc2 (->clj loc)
                              coords (:coords loc2)
                              ts (st/now)
                              dtf (new intl/DateTimeFormat)
                              timezone (or (when-let [resolved (.-resolved dtf)]
                                             (.-timeZone resolved))
                                           (when-let [resolved (.resolvedOptions dtf)]
                                             (.-timeZone resolved)))
                              entry {:md        (str loc2)
                                     :timestamp  ts
                                     :new-entry  true
                                     :timezone   timezone
                                     :utc-offset (.getTimezoneOffset (new js/Date))
                                     :coords    coords
                                     :perm_tags #{"#locationtracking"}
                                     :latitude  (:latitude coords)
                                     :longitude (:longitude coords)}]
                          (put-fn [:entry/new entry])))
          on-motion (fn [m] (js/console.warn "motion" m))
          on-activity (fn [act] (js/console.warn "activity" act))
          on-error (fn [err] (js/console.error err))
          on-ready (fn [state]
                     (js/console.warn "ready" state)
                     (.start BackgroundGeolocation
                             (fn [] (js/console.warn "started-watching"))))]
      (.onLocation BackgroundGeolocation on-location on-error)
      ;(.onActivityChange BackgroundGeolocation on-activity)
      ;(.onMotionChange BackgroundGeolocation on-motion)
      (.ready BackgroundGeolocation cfg on-ready)
      {:state state})
    (catch :default e (shared/alert (str "geolocation not available: " e)))))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {}})
