(ns meo.electron.renderer.helpers
  (:require [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as p]
            [goog.dom.Range]
            [globalize :as globalize]
            [cldr-data :as cldr-data]
            [iana-tz-data :as iana-tz-data]
            [moment]))

(defn target-val [ev] (-> ev .-nativeEvent .-target .-value))

(defn send-w-geolocation
  "Calls geolocation, sends entry enriched by geo information inside the
  callback function"
  [data put-fn]
  (.getCurrentPosition
    (.-geolocation js/navigator)
    (fn [pos]
      (let [coords (.-coords pos)
            updated (merge data {:latitude  (.-latitude coords)
                                 :longitude (.-longitude coords)})]
        (put-fn [:entry/geo-enrich updated])))
    (fn [err] (prn err))))

(def timezone
  (or (when-let [resolved (.-resolved (new js/Intl.DateTimeFormat))]
        (.-timeZone resolved))
      (when-let [resolved (.resolvedOptions (new js/Intl.DateTimeFormat))]
        (.-timeZone resolved))))

(.load globalize (.entireSupplemental cldr-data))
(.load globalize (.entireMainFor cldr-data "en" "de" "fr" "es"))
(.loadTimeZone globalize iana-tz-data)

(def locales
  {:en (globalize. "en")
   :de (globalize. "de")
   :fr (globalize. "fr")
   :es (globalize. "es")})

(defn localize-date [s locale]
  (when-let [locale (get locales locale)]
    (.formatDate locale (.toDate (moment. s)) (clj->js {:date "full"}))))

(defn localize-datetime [s locale]
  (when-let [locale (get locales locale)]
    (.formatDate locale (.toDate (moment. s)) (clj->js {:datetime "medium"}))))

(defn new-entry-fn
  "Create a new, empty entry. The opts map is merged last with the generated
   entry, thus keys can be overwritten here.
   Caveat: the timezone detection currently only works in Chrome. TODO: check
   "
  [put-fn opts run-fn]
  (fn [_ev]
    (let [ts (st/now)
          entry (merge (p/parse-entry "")
                       {:timestamp  ts
                        :timezone   timezone
                        :utc-offset (.getTimezoneOffset (new js/Date))}
                       opts)]
      (put-fn [:entry/new entry])
      (send-w-geolocation entry put-fn)
      (when run-fn (run-fn)))))

(defn prevent-default [ev] (.preventDefault ev))

(defn add [x y] (+ (or x 0) (or y 0)))

(defn update-numeric [entry path put-fn]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (js/parseFloat v))
          updated (assoc-in entry path parsed)]
      (when parsed
        (put-fn [:entry/update-local updated])))))

(def ymd-format "YYYY-MM-DD")
(defn n-days-ago [n] (.subtract (moment.) n "d"))
(defn n-days-ago-fmt [n] (.format (n-days-ago n) ymd-format))
(defn format-time [m] (.format (moment m) "YYYY-MM-DDTHH:mm"))
(defn hh-mm [m] (.format (moment m) "HH:mm"))
(defn ymd [m] (.format (moment m) ymd-format))

(defn m-to-hh-mm [m]
  (let [t (moment (* m 60 1000))]
    (.format (.utc t) "HH:mm")))

(defn s-to-hh-mm [m]
  (let [t (moment (* m 1000))]
    (.format (.utc t) "HH:mm")))

(defn s-to-hh-mm-ss [s]
  (let [t (moment (* s 1000))]
    (.format (.utc t) "HH:mm:ss")))

(defn get-stats
  "Retrieves stats for the last n days."
  [stats-key n m put-fn]
  (let [days (map n-days-ago-fmt (reverse (range n)))]
    (put-fn (with-meta
              [:stats/get {:days (mapv (fn [d] {:date-string d}) days)
                           :type stats-key}]
              m))))

(defn keep-updated [stats-key n local last-update put-fn]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (>= last-update last-fetched)
      (swap! local assoc-in [:last-fetched stats-key] (st/now))
      (get-stats stats-key n (:meta last-update {}) put-fn))))

(defn keep-updated2
  [stats-key day local last-update put-fn]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (> last-update last-fetched)
      (swap! local assoc-in [:last-fetched stats-key] (st/now))
      (put-fn [:stats/get {:days [{:date-string day}] :type stats-key}]))))

