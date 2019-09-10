(ns meins.components.geolocation
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.ui.shared :as shared :refer [platform-os]]
            ["intl" :as intl]
            ["realm" :as realm]
            [cljs-bean.core :refer [bean ->clj ->js]]
            ["react-native-background-geolocation" :default BgGeo]
            [cljs.tools.reader.edn :as edn]
            [meins.helpers :as h]
            [meins.ui.db :as uidb]))

(def accuracy
  (if (= platform-os "ios")
    (.-DESIRED_ACCURACY_NAVIGATION BgGeo)
    (.-DESIRED_ACCURACY_HIGH BgGeo)))

(def cfg
  (->js
    {:reset           true
     :desiredAccuracy accuracy
     :distanceFilter  10
     :stopTimeout     5
     :debug           false
     :logLevel        (.-LOG_LEVEL_DEBUG BgGeo)
     :stopOnTerminate false
     :startOnBoot     true
     :batchSync       false
     :autoSync        false}))

(defn next-save-ts [ts]
  (let [interval (* 5 60 1000)
        n (js/Math.ceil (/ ts interval))]
    (* interval n)))

(defn empty-state []
  {:next-save (next-save-ts (st/now))})

(defn stop [_]
  (.stop BgGeo)
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
                          :perm_tags  #{"#locationtracking"}}
                   clear-cb #(js/console.warn "geo db cleared")]
               (put-fn [:entry/new entry])
               (.destroyLocations BgGeo clear-cb)))]
    (.getLocations BgGeo cb))
  {})

(defn email-logs [{:keys [put-fn]}]
  (-> (.emailLog BgGeo "")
      (.then #(js/console.warn "BgGeo logs sent")))
  {})

(defn start [{:keys []}]
  (js/console.warn "BgGeo start")
  (try
    (let [on-ready (fn [state]
                     (js/console.warn "ready" state)
                     (.start BgGeo
                             (fn [] (js/console.warn "started-watching"))))]
      (.ready BgGeo cfg on-ready))
    (catch :default e (shared/alert (str "geolocation error: " e))))
  {})

(defn state-fn [_put-fn]
  (let [state (atom (empty-state))]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:bg-geo/start      start
                 :bg-geo/save       save
                 :bg-geo/email-logs email-logs
                 :bg-geo/stop       stop}})
