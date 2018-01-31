(ns meo.ios.activity
  (:require [matthiasn.systems-toolbox.component :as st]))

(enable-console-print!)

(def activity-recognition (js/require "react-native-activity-recognition"))
(def moment (js/require "moment"))

(defn monitor-activity [{:keys [current-state put-fn]}]
  (let [detection-interval-ms 10000
        cb (fn [detected] (put-fn [:activity/current
                                   (js->clj detected :keywordize-keys true)]))
        unsubscribe (.subscribe activity-recognition cb)
        new-state (assoc-in current-state [:unsubscribe] unsubscribe)]
    (.start activity-recognition detection-interval-ms)
    {:new-state new-state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:activity/monitor monitor-activity}})
