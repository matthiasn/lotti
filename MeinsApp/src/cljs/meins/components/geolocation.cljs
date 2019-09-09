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
     :distanceFilter         10
     ;:locationUpdateInterval 60000
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
  {:next-save (next-save-ts (st/now))})

(defn stop [_]
  (.stop BackgroundGeolocation)
  {})

(defn start [{:keys [cmp-state put-fn]}]
  (js/console.warn "BgGeo start")
  (try
    (let [on-location (fn [loc]
                        (let [loc2 (->clj loc)
                              {:keys [latitude longitude]} (:coords loc2)
                              ts (h/iso8601-to-millis (:timestamp loc2))
                              bg-geo {:timestamp ts
                                      :latitude  latitude
                                      :longitude longitude
                                      :edn       (pr-str loc2)}]
                          (try
                            (.write @uidb/realm-db
                                    (fn []
                                      (let [db-entry (->js bg-geo)]
                                        (.create @uidb/realm-db "BgGeo" db-entry true))))
                            (catch :default e (js/console.error e)))))
          on-error (fn [err] (js/console.error err))
          on-ready (fn [state]
                     (js/console.warn "ready" state)
                     (.start BackgroundGeolocation
                             (fn [] (js/console.warn "started-watching"))))]
      (.onLocation BackgroundGeolocation on-location on-error)
      (.ready BackgroundGeolocation cfg on-ready))
    (catch :default e (shared/alert (str "geolocation not available: " e))))
  {})

(defn save [{:keys [cmp-state put-fn]}]
  (js/console.warn "BgGeo save")
  (let [open (some-> @uidb/realm-db
                     (.objects "BgGeo")
                     (.filtered "sync == \"OPEN\"")
                     (.sorted "timestamp" false)
                     (.slice 0 500))
        _ (js/console.warn open)
        ts (st/now)
        dtf (new intl/DateTimeFormat)
        timezone (or (when-let [resolved (.-resolved dtf)]
                       (.-timeZone resolved))
                     (when-let [resolved (.resolvedOptions dtf)]
                       (.-timeZone resolved)))
        locations (mapv (fn [x] (edn/read-string (.-edn x))) open)
        entry {:md         (str (count locations) " locations recorded")
               :timestamp  ts
               :new-entry  true
               :timezone   timezone
               :utc-offset (.getTimezoneOffset (new js/Date))
               :bg-geo     locations
               :perm_tags  #{"#locationtracking"}}]
    (put-fn [:entry/new entry])
    (doseq [db-item open]
      (.write @uidb/realm-db #(set! (.-sync db-item) "SYNCED"))))
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
