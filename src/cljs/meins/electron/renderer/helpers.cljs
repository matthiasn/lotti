(ns meins.electron.renderer.helpers
  (:require ["cldr-data" :as cldr-data]
            ["electron" :refer [remote]]
            ["globalize" :as globalize]
            ["iana-tz-data" :as iana-tz-data]
            ["moment" :as moment]
            ["ngeohash" :as geohash]
            ["path" :refer [normalize]]
            [cljs.nodejs :refer [process]]
            [clojure.string :as s]
            [goog.dom.Range]
            [meins.common.utils.misc :as m]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.parse :as p]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [moment-duration-format]
            [reagent.core :as rc]
            [taoensso.timbre :refer [debug error info]]))

(defn target-val [ev] (-> ev .-nativeEvent .-target .-value))

(defn send-w-geolocation
  "Calls geolocation, sends entry enriched by geo information inside the callback function"
  [entry]
  (.getCurrentPosition
    (.-geolocation js/navigator)
    (fn [pos]
      (let [coords (.-coords pos)
            lat (.-latitude coords)
            lng (.-longitude coords)
            updated {:timestamp (:timestamp entry)
                     :geohash   (geohash/encode lat lng 9)
                     :latitude  lat
                     :longitude lng}]
        (js/window.setTimeout #(emit [:entry/update-local updated]) 100)))
    (fn [err]
      (error "while getting geolocation:" err)
      (.log js/console err))
    (clj->js {:timeout            30000
              :maximumAge         300000
              :enableHighAccuracy true})))

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

(defn create-entry [opts]
  (let [ts (stc/now)
        entry (merge (p/parse-entry "")
                     {:timestamp  ts
                      :timezone   timezone
                      :utc-offset (.getTimezoneOffset (new js/Date))}
                     opts)]
    (emit [:entry/update entry])
    (send-w-geolocation entry)
    entry))

(defn new-entry
  "Create a new, empty entry. The opts map is merged last with the generated
   entry, thus keys can be overwritten here.
   Caveat: the timezone detection currently only works in Chrome. TODO: check"
  ([]
   (new-entry {}))
  ([opts]
   (new-entry opts nil))
  ([opts run-fn]
   (fn [_ev]
     (let [entry (create-entry opts)]
       (when run-fn (run-fn entry))
       entry))))

(defn prevent-default [ev] (.preventDefault ev))

(defn add [x y] (+ (or x 0) (or y 0)))

(defn update-numeric [entry path]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (js/parseFloat v))
          updated (assoc-in entry path parsed)]
      (when parsed
        (emit [:entry/update-local updated])))))

(defn update-time [entry path]
  (fn [ev]
    (let [v (.. ev -target -value)
          parsed (when (seq v) (.asMinutes (.duration moment v)))
          updated (assoc-in entry path parsed)]
      (when parsed
        (emit [:entry/update-local updated]))
      v)))

(def ymd-format "YYYY-MM-DD")
(defn n-days-ago [n] (.subtract (moment.) n "d"))
(defn n-days-ago-fmt [n] (.format (n-days-ago n) ymd-format))
(defn format-time [m] (.format (moment m) "YYYY-MM-DDTHH:mm"))
(defn hh-mm [m] (.format (moment m) "HH:mm"))
(defn ymd [m] (.format (moment m) ymd-format))
(defn ymd-to-ts [s] (.valueOf (moment s ymd-format)))

(defn m-to-hh-mm [m]
  (let [t (moment (* m 60 1000))]
    (.format (.utc t) "HH:mm")))

(defn s-to-hh-mm [s]
  (let [t (moment (* s 1000))]
    (.format (.utc t) "HH:mm")))

(defn s-to-hh-mm-ss [s]
  (if (< s (* 24 60 60))
    (let [t (moment (* s 1000))]
      (.format (.utc t) "HH:mm:ss"))
    (let [dur (.duration moment s "seconds")]
      (.format dur "d:HH:mm:ss"))))

(defn s-to-mm-ss-ms [ms]
  (let [t (moment ms)]
    (.format (.utc t) "mm:ss:SSS")))

(defn time-ago [ms-ago]
  (let [dur (.duration moment ms-ago)]
    (.humanize dur false)))

(defn visit-duration
  "Formats duration string."
  [entry]
  (let [arrival-ts (:arrival_timestamp entry)
        depart-ts (:departure_timestamp entry)
        secs (when (and arrival-ts depart-ts)
               (let [dur (- depart-ts arrival-ts)]
                 (if (int? dur) (/ dur 1000) dur)))]
    (when (and secs (< secs 99999999))
      (s-to-hh-mm secs))))

(defn get-stats
  "Retrieves stats for the last n days."
  [stats-key n m]
  (let [days (map n-days-ago-fmt (reverse (range n)))]
    (emit (with-meta
            [:stats/get {:days (mapv (fn [d] {:date_string d}) days)
                         :type stats-key}]
            m))))

(defn keep-updated [stats-key n local last-update]
  (let [last-fetched (get-in @local [:last-fetched stats-key] 0)
        last-update (:last-update last-update)]
    (when (or (>= last-update last-fetched)
              (not= n (get-in @local [stats-key :n])))
      (swap! local assoc-in [stats-key :n] n)
      (swap! local assoc-in [:last-fetched stats-key] (stc/now))
      (get-stats stats-key n (:meta last-update {})))))

(defn str-contains-lc?
  "Tests if string s contains substring. Both are converted to lowercase.
   Returns nil when not both of the arguments are strings."
  [s substring]
  (when (and (string? s) (string? substring))
    (s/includes? (m/lower-case s) (m/lower-case substring))))

(def user-data (.getPath (aget remote "app") "userData"))
(def rp (.-resourcesPath process))
(def repo-dir (s/includes? (m/lower-case rp) "electron"))
(def photos (str (if repo-dir ".." user-data) "/data/images/"))

(defn media-path [path file]
  (normalize (str (if repo-dir
                    "/tmp/meins"
                    user-data)
                  path file)))

(defn thumbs-256 [file] (media-path "/data/thumbs/256/" file))
(defn thumbs-512 [file] (media-path "/data/thumbs/512/" file))
(defn thumbs-2048 [file] (media-path "/data/thumbs/2048/" file))

(defn audio-path [file] (media-path "/data/audio/" file))

(def export (str (if repo-dir "/tmp/meins" user-data) "/data/export/"))

(defn to-day [ymd pvt]
  (emit [:cal/to-day {:day ymd}])
  (emit [:gql/query {:file "logged-by-day.gql"
                     :id   :logged-by-day
                     :prio 13
                     :args [ymd]}])
  (emit [:gql/query {:file "briefing.gql"
                     :id   :briefing
                     :prio 12
                     :args [ymd @pvt]}]))

(defn error-boundary
  "Error boundary for isolating React components. From:
  https://github.com/reagent-project/reagent/blob/master/test/reagenttest/testreagent.cljs#L1035
  Also see: https://reactjs.org/blog/2017/07/26/error-handling-in-react-16.html"
  [_comp]
  (let [err (atom nil)]
    (rc/create-class
      {:component-did-catch (fn [_this e _info]
                              (reset! err e))
       :reagent-render      (fn [comp]
                              (if @err
                                (do (error @err)
                                    [:div "Something went wrong."])
                                comp))})))

(defn keydown-fn [entry path]
  (fn [ev]
    (let [text (aget ev "target" "innerText")
          updated (assoc-in entry path text)
          key-code (.. ev -keyCode)
          meta-key (.. ev -metaKey)]
      (when (and meta-key (= key-code 83))                  ; CMD-s pressed
        (emit [:entry/update updated])
        (.preventDefault ev)))))

(defn key-down-save [entry]
  (fn [ev]
    (let [key-code (.. ev -keyCode)
          meta-key (.. ev -metaKey)]
      (when (and meta-key (= key-code 83))                  ; CMD-s pressed
        (emit [:entry/update entry])
        (.preventDefault ev)))))
