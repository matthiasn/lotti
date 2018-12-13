(ns meo.electron.renderer.helpers
  (:require [matthiasn.systems-toolbox.component :as st]
            [meo.common.utils.parse :as p]
            [goog.dom.Range]
            [reagent.core :as rc]
            [taoensso.timbre :refer-macros [info debug error]]
            [path :refer [normalize]]
            [globalize :as globalize]
            [cldr-data :as cldr-data]
            [iana-tz-data :as iana-tz-data]
            [moment]
            [electron :refer [remote]]
            [cljs.nodejs :refer [process]]
            [clojure.string :as s]))

(defn target-val [ev] (-> ev .-nativeEvent .-target .-value))

(defn send-w-geolocation
  "Calls geolocation, sends entry enriched by geo information inside the callback function"
  [entry put-fn]
  (.getCurrentPosition
    (.-geolocation js/navigator)
    (fn [pos]
      (let [coords (.-coords pos)
            updated {:timestamp (:timestamp entry)
                     :latitude  (.-latitude coords)
                     :longitude (.-longitude coords)}]
        (put-fn [:entry/update-local updated])))
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
    (.formatDate locale (.toDate (moment. s)) (clj->js {:date "medium"}))))

(defn localize-datetime [s locale]
  (when-let [locale (get locales locale)]
    (.formatDate locale (.toDate (moment. s)) (clj->js {:datetime "medium"}))))

(defn localize-datetime-full [s locale]
  (when-let [locale (get locales locale)]
    (.formatDate locale (.toDate (moment. s)) (clj->js {:skeleton "yMMMEdHm"}))))

(defn create-entry [put-fn opts]
  (let [ts (st/now)
        entry (merge (p/parse-entry "")
                     {:timestamp  ts
                      :timezone   timezone
                      :utc-offset (.getTimezoneOffset (new js/Date))}
                     opts)]
    (put-fn [:entry/update entry])
    (send-w-geolocation entry put-fn)
    entry))

(defn new-entry
  "Create a new, empty entry. The opts map is merged last with the generated
   entry, thus keys can be overwritten here.
   Caveat: the timezone detection currently only works in Chrome. TODO: check"
  ([put-fn]
    (new-entry put-fn {} nil))
  ([put-fn opts]
    (new-entry put-fn opts nil))
  ([put-fn opts run-fn]
   (fn [_ev]
     (let [entry (create-entry put-fn opts)]
       (when run-fn (run-fn entry))
       entry))))

(defn prevent-default [ev] (.preventDefault ev))

(defn add [x y] (+ (or x 0) (or y 0)))

(defn update-numeric [entry path put-fn]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (js/parseFloat v))
          updated (assoc-in entry path parsed)]
      (when parsed
        (put-fn [:entry/update-local updated])))))

(defn update-time [entry path put-fn]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (.asMinutes (.duration moment v)))
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

(defn s-to-hh-mm [s]
  (let [t (moment (* s 1000))]
    (.format (.utc t) "HH:mm")))

(defn s-to-hh-mm-ss [s]
  (let [t (moment (* s 1000))]
    (.format (.utc t) "HH:mm:ss")))

(defn s-to-mm-ss-ms [ms]
  (let [t (moment ms)]
    (.format (.utc t) "mm:ss:SSS")))

(defn visit-duration
  "Formats duration string."
  [entry]
  (let [arrival-ts (:arrival_timestamp entry)
        depart-ts (:departure_timestamp entry)
        secs (when (and arrival-ts depart-ts)
               (let [dur (- depart-ts arrival-ts)]
                 (if (int? dur) (/ dur 1000) dur)))]
    (when (and secs (< secs 99999999))
      (str "Visit: " (s-to-hh-mm secs)))))

(defn get-stats
  "Retrieves stats for the last n days."
  [stats-key n m put-fn]
  (let [days (map n-days-ago-fmt (reverse (range n)))]
    (put-fn (with-meta
              [:stats/get {:days (mapv (fn [d] {:date_string d}) days)
                           :type stats-key}]
              m))))

(defn keep-updated [stats-key n local last-update put-fn]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (or (>= last-update last-fetched)
              (not= n (get-in @local [stats-key :n])))
      (swap! local assoc-in [stats-key :n] n)
      (swap! local assoc-in [:last-fetched stats-key] (st/now))
      (get-stats stats-key n (:meta last-update {}) put-fn))))

(defn str-contains-lc?
  "Tests if string s contains substring. Both are converted to lowercase.
   Returns nil when not both of the arguments are strings."
  [s substring]
  (when (and (string? s) (string? substring))
    (s/includes? (s/lower-case s) (s/lower-case substring))))

(def user-data (.getPath (aget remote "app") "userData"))
(def rp (.-resourcesPath process))
(def repo-dir (s/includes? (s/lower-case rp) "electron"))
(def photos (str (if repo-dir ".." user-data) "/data/images/"))

(defn media-path [path file]
  (normalize (str (if repo-dir
                    (.cwd process)
                    user-data)
                  path file)))

(defn thumbs-256 [file] (media-path  "/data/thumbs/256/" file))
(defn thumbs-512 [file] (media-path  "/data/thumbs/512/" file))
(defn thumbs-2048 [file] (media-path  "/data/thumbs/2048/" file))

(defn audio-path [file] (media-path "/data/audio/" file))

(def export (str (if repo-dir ".." user-data) "/data/export/"))

(defn to-day [ymd pvt put-fn]
  (put-fn [:cal/to-day {:day ymd}])
  (put-fn [:gql/query {:file "logged-by-day.gql"
                       :id   :logged-by-day
                       :prio 13
                       :args [ymd]}])
  (put-fn [:gql/query {:file "briefing.gql"
                       :id   :briefing
                       :prio 12
                       :args [ymd @pvt]}]))

(defn error-boundary
  "Error boundary for isolating React components. From:
  https://github.com/reagent-project/reagent/blob/master/test/reagenttest/testreagent.cljs#L1035
  Also see: https://reactjs.org/blog/2017/07/26/error-handling-in-react-16.html"
  [comp]
  (let [err (atom nil)]
    (rc/create-class
      {:component-did-catch (fn [this e info]
                              (reset! err e))
       :reagent-render      (fn [comp]
                              (if @err
                                (do (error @err)
                                    [:div "Something went wrong."])
                                comp))})))

(defn keydown-fn [entry k put-fn]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry [k] text)
          key-code (.. ev -keyCode)
          meta-key (.. ev -metaKey)]
      (when (and meta-key (= key-code 83))                  ; CMD-s pressed
        (put-fn [:entry/update updated])
        (.preventDefault ev)))))


(defn key-down-save [entry put-fn]
  (fn [ev]
    (let [key-code (.. ev -keyCode)
          meta-key (.. ev -metaKey)]
      (when (and meta-key (= key-code 83))                  ; CMD-s pressed
        (put-fn [:entry/update entry])
        (.preventDefault ev)))))
