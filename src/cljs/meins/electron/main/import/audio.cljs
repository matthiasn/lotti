(ns meins.electron.main.import.audio
  (:require ["glob" :as glob :refer [sync]]
            ["fs" :refer [copyFileSync existsSync readFileSync]]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            ["moment" :as moment]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as spec]
            ["child_process" :refer [spawn]]
            [clojure.pprint :as pp]
            [expound.alpha :as exp]
            [clojure.string :as s]))

(def audio-path-atom (atom ""))

(defn convert-audio-entry [data]
  (let [ts (get data "timestamp")
        text (str (h/format-time ts) " Audio")
        geolocation (get data "geolocation")
        entry {:timestamp  ts
               :md         text
               :text       text
               :mentions   #{}
               :utc-offset (get data "utcOffset")
               :audio_file (get data "audioFile")
               :timezone   (get data "timezone")
               :tags       #{"#audio" "#import"}
               :perm_tags  #{"#audio" "#task"}
               :longitude  (get geolocation "longitude")
               :latitude   (get geolocation "latitude")
               :vclock     (get data "vectorClock")}]
    entry))

(defn convert-new-audio-entry [json]
  (let [data (get json "data")
        date-from (get json "dateFrom")
        ts (.valueOf (moment date-from))
        text (str (h/format-time ts) " Audio")
        geolocation (get json "geolocation")
        entry {:timestamp  ts
               :md         text
               :text       text
               :mentions   #{}
               :utc-offset (get json "utcOffset")
               :audio_file (get data "audioFile")
               :timezone   (get json "timezone")
               :tags       #{"#audio" "#import"}
               :perm_tags  #{"#audio" "#task"}
               :longitude  (get geolocation "longitude")
               :latitude   (get geolocation "latitude")
               :vclock     (get json "vectorClock")}]
    entry))

(defn time-recording-entry [json]
  (let [data (get json "data")
        entry (convert-new-audio-entry json)
        entry-ts (:timestamp entry)
        subentry (select-keys entry [:utc-offset
                                     :timezone
                                     :longitude
                                     :latitude])
        comment (merge subentry
                       {:timestamp      (+ entry-ts 1000)
                        :entry_type     :pomodoro
                        :comment_for    entry-ts
                        :text           "recording"
                        :md             "- recording"
                        :completed_time (/ (get data "duration")
                                           1000000)})]
    comment))

(defn import-audio-files [path put-fn]
  (let [files (sync (str path "/audio/**/*.json"))]
    (doseq [json-file files]
      (when-not (s/includes? json-file "trash")
        (let [data (h/parse-json json-file)
              entry (convert-new-audio-entry data)
              comment (time-recording-entry data)
              file (str/replace json-file ".json" "")
              audio-file (:audio_file entry)
              audio-file-path (str @audio-path-atom "/" audio-file)]
          (when-not (existsSync audio-file-path)
            (when (existsSync file)
              (copyFileSync file audio-file-path)
              (when (spec/valid? :meins.entry/spec entry)
                (pp/pprint entry)
                (put-fn [:entry/save-initial entry]))
              (when (spec/valid? :meins.entry/spec comment)
                (pp/pprint comment)
                (put-fn [:entry/save-initial comment])))))))))
