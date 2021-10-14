(ns meins.electron.main.import
  (:require ["glob" :as glob :refer [sync]]
            ["fs" :refer [copyFileSync existsSync readFileSync]]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            [cljs.spec.alpha :as s]
            [clojure.pprint :as pp]))

(def data-path (:data-path rt/runtime-info))
(def audio-path (:audio-path rt/runtime-info))

(defn parse-json [file]
  (let [json (.parse js/JSON (readFileSync file))
        data (js->clj json)]
    data))

(defn convert-entry [data]
  (let [entry {:timestamp  (get data "timestamp")
               :md         "import audio"
               :text       "import audio"
               :mentions   #{}
               :utc-offset (get data "utcOffset")
               :audio_file (get data "audioFile")
               :timezone   (get data "timezone")
               :tags       #{"#audio" "#import"}
               :perm_tags  #{"#audio" "#task"}
               :longitude  (get data "longitude")
               :latitude   (get data "latitude")
               :vclock     (get data "vectorClock")}]
    entry))

(defn time-recording-entry [data]
  (let [entry (convert-entry data)
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

(defn list-dir [path put-fn]
  (let [files (sync (str path "/**/*.json"))]
    (doseq [json-file files]
      (let [data (parse-json json-file)
            entry (convert-entry data)
            comment (time-recording-entry data)
            file (str/replace json-file ".json" "")
            audio-file (:audio_file entry)
            audio-file-path (str audio-path "/" audio-file)]
        (when-not (existsSync audio-file-path)
          (when (existsSync file)
            (copyFileSync file audio-file-path)))
        (when (s/valid? :meins.entry/spec entry)
          (pp/pprint entry)
          (put-fn [:entry/update entry]))
        (when (s/valid? :meins.entry/spec comment)
          (pp/pprint comment)
          (put-fn [:entry/update comment]))))))

(defn import-audio [{:keys [msg-payload put-fn]}]
  (let [path (:directory msg-payload)]
    (info "import-audio:" path)
    (list-dir path put-fn)))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/audio import-audio}})
