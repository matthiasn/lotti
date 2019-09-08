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
    {:reset                  true
     :desiredAccuracy        (.-DESIRED_ACCURACY_HIGH BackgroundGeolocation)
     :distanceFilter         50
     :locationUpdateInterval 60000
     ;:useSignificantChanges  true
     :stopTimeout            2
     :debug                  false
     :logLevel               (.-LOG_LEVEL_INFO BackgroundGeolocation)
     :stopOnTerminate        false
     :startOnBoot            true
     :batchSync              false
     :autoSync               false}))

(defn next-save-ts [ts]
  (let [interval (* 5 60 1000)
        n (js/Math.ceil (/ ts interval))]
    (* interval n)))

(defn empty-state []
  {:next-save (next-save-ts (st/now))
   :locations []})

(defn stop [_]
  (.stop BackgroundGeolocation)
  {})

(defn start [{:keys [cmp-state put-fn]}]
  (try
    (let [save-entry (fn []
                       (let [ts (st/now)
                             dtf (new intl/DateTimeFormat)
                             timezone (or (when-let [resolved (.-resolved dtf)]
                                            (.-timeZone resolved))
                                          (when-let [resolved (.resolvedOptions dtf)]
                                            (.-timeZone resolved)))
                             locations (:locations @cmp-state)
                             entry {:md         (str (count locations) " locations recorded")
                                    :timestamp  ts
                                    :new-entry  true
                                    :timezone   timezone
                                    :utc-offset (.getTimezoneOffset (new js/Date))
                                    :bg-geo     locations
                                    :perm_tags  #{"#locationtracking"}}]
                         (put-fn [:entry/new entry])))
          on-location (fn [loc]
                        (let [loc2 (->clj loc)
                              now (st/now)]
                          (swap! cmp-state update :locations conj loc2)
                          (when (> now (:next-save @cmp-state))
                            (save-entry)
                            (reset! cmp-state (empty-state)))))
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
      (.ready BackgroundGeolocation cfg on-ready))
    (catch :default e (shared/alert (str "geolocation not available: " e))))
  {})

(defn state-fn [put-fn]
  (let [state (atom (empty-state))]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:bg-geo/start start
                 :bg-geo/stop  stop}})
