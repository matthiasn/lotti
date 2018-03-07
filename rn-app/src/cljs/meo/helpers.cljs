(ns meo.helpers
  (:require [matthiasn.systems-toolbox.component :as st]
            [goog.dom.Range]
            [meo.utils.parse :as p]))

(set! js/moment (js/require "moment"))

(defn send-w-geolocation
  "Calls geolocation, sends entry enriched by geo information inside the
  callback function"
  [ts put-fn]
  (.getCurrentPosition
    (.-geolocation js/navigator)
    (fn [pos]
      (let [loc (js->clj (.-coords pos) :keywordize-keys true)]
        (put-fn [:entry/persist {:timestamp ts
                                 :location  loc
                                 :latitude  (:latitude loc)
                                 :longitude (:longitude loc)}])))
    (fn [err] (prn err))
    (clj->js {:enableHighAccuracy true :maximumAge 60000})))

(defn new-entry-fn [put-fn opts run-fn]
  (fn [_ev]
    (let [ts (st/now)
          timezone (or (when-let [resolved (.-resolved (new js/Intl.DateTimeFormat))]
                         (.-timeZone resolved))
                       (when-let [resolved (.resolvedOptions (new js/Intl.DateTimeFormat))]
                         (.-timeZone resolved)))
          entry (merge (p/parse-entry "")
                       {:timestamp  ts
                        :new-entry  true
                        :timezone   timezone
                        :utc-offset (.getTimezoneOffset (new js/Date))}
                       opts)]
      (put-fn [:entry/new entry])
      (send-w-geolocation ts put-fn)
      (when run-fn (run-fn)))))

(defn prevent-default [ev] (.preventDefault ev))

(defn add [x y] (+ (or x 0) (or y 0)))

(defn update-numeric [entry path put-fn]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (js/parseFloat v))
          updated (assoc-in entry path parsed)]
      (when parsed
        (put-fn [:entry/update updated])))))

(def ymd-format "YYYY-MM-DD")
(defn n-days-ago [n] (.subtract (js/moment.) n "d"))
(defn n-days-ago-fmt [n] (.format (n-days-ago n) ymd-format))
(defn format-time [m] (.format (js/moment m) "YYYY-MM-DD HH:mm"))
(defn img-fnt [m] (.format (js/moment m) "YYYYMMDD_HHmmss_SSS"))
(defn hh-mm [m] (.format (js/moment m) "HH:mm"))
(defn ymd [m] (.format (js/moment m) ymd-format))
(defn m-to-hh-mm [m]
  (let [t (js/moment (* m 60 1000))]
    (.format (.utc t) "HH:mm")))

(defn get-stats
  "Retrieves stats for the last n days."
  [stats-key n m put-fn]
  (let [days (map n-days-ago-fmt (reverse (range n)))]
    (put-fn (with-meta
              [:stats/get {:days (mapv (fn [d] {:date-string d}) days)
                           :type stats-key}]
              m))))

(defn keep-updated
  [stats-key n local last-update put-fn]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (> last-update last-fetched)
      (swap! local assoc-in [:last-fetched stats-key] (st/now))
      (get-stats stats-key n (:meta last-update {}) put-fn))))

(defn keep-updated2
  [stats-key day local last-update put-fn]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (> last-update last-fetched)
      (swap! local assoc-in [:last-fetched stats-key] (st/now))
      (put-fn [:stats/get {:days [{:date-string day}] :type stats-key}]))))

