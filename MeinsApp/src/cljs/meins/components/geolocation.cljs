(ns meins.components.geolocation
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :as shared]
            ["intl" :as intl]
            ["realm" :as realm]
            [cljs-bean.core :refer [bean ->clj ->js]]
            ["react-native-background-geolocation" :as rn-bg-geo]
            [cljs.tools.reader.edn :as edn]
            [meins.helpers :as h]
            [meins.ui.db :as uidb]))

(def BackgroundGeolocation (aget rn-bg-geo "default"))

(def cfg
  (clj->js
    {:reset                  true
     :desiredAccuracy        (.-DESIRED_ACCURACY_HIGH BackgroundGeolocation)
     :distanceFilter         50
     ;:useSignificantChanges  true
     :stopTimeout            5
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
  {:next-save (next-save-ts (st/now))})

(defn stop [_]
  (.stop BackgroundGeolocation)
  {})

(defn save [{:keys [put-fn]}]
  (let [cb (fn [loc]
             (js/console.warn "BgGeo save locations" loc)
             (let [locations (->clj loc)
                   ts (st/now)
                   dtf (new intl/DateTimeFormat)
                   timezone (or (when-let [resolved (.-resolved dtf)]
                                  (.-timeZone resolved))
                                (when-let [resolved (.resolvedOptions dtf)]
                                  (.-timeZone resolved)))
                   entry {:md         (str (count locations) " locations recorded")
                          :timestamp  ts
                          :new-entry  true
                          :timezone   timezone
                          :utc-offset (.getTimezoneOffset (new js/Date))
                          :bg-geo     locations
                          :perm_tags  #{"#locationtracking"}}]
               (put-fn [:entry/new entry])))]
    (.getLocations BackgroundGeolocation cb))
  {})

(defn start [{:keys []}]
  (js/console.warn "BgGeo start")
  (try
    (let [on-ready (fn [state]
                     (js/console.warn "ready" state)
                     (.start BackgroundGeolocation
                             (fn [] (js/console.warn "started-watching"))))]
      (.ready BackgroundGeolocation cfg on-ready))
    (catch :default e (shared/alert (str "geolocation error: " e))))
  {})

(defn state-fn [_put-fn]
  (let [state (atom (empty-state))]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:bg-geo/start start
                 :bg-geo/save  save
                 :bg-geo/stop  stop}})
