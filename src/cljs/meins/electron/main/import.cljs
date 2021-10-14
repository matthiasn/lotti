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

(defn read-entry [file]
  (let [json (.parse js/JSON (readFileSync file))
        data (js->clj json)
        entry {:timestamp  (get data "timestamp")
               :md         ""
               :text       ""
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

(defn list-dir [path read-fn put-fn]
  (let [files (sync (str path "/**/*.json"))]
    (doseq [json-file files]
      (let [entry (read-fn json-file)
            file (str/replace json-file ".json" "")
            audio-file (:audio_file entry)
            audio-file-path (str audio-path "/" audio-file)]
        (when-not (existsSync audio-file-path)
          (when (existsSync file)
            (copyFileSync file audio-file-path)))
        (when (s/valid? :meins.entry/spec entry)
          (pp/pprint entry)
          (put-fn [:entry/update entry]))))))

(defn import-audio [{:keys [msg-payload put-fn]}]
  (let [path (:directory msg-payload)]
    (info "import-audio:" path)
    (list-dir path read-entry put-fn)))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/audio import-audio}})
