(ns meins.electron.main.import
  (:require ["glob" :as glob :refer [sync]]
            ["os" :as os]
            ["fs" :refer [copyFileSync existsSync readFileSync]]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]))

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
               :perm_tags  #{"#audio"}
               :lng        (get data "longitude")
               :lat        (get data "latitude")
               :vclock     (get data "vectorClock")}]
    entry))

(defn list-dir [path read-fn]
  (let [files (sync (str path "/**/*.json"))]
    (doseq [json-file files]
      (let [entry (read-fn json-file)
            file (str/replace json-file ".json" "")
            audio-file (:audio_file entry)
            audio-file-path (str audio-path "/" audio-file)]
        (when-not (existsSync audio-file-path)
          (copyFileSync file audio-file-path))
        (info entry)))))

(defn import-audio [{:keys [put-fn]}]
  (info "import-audio" data-path)
  (let [home (.homedir os)
        path (str home "/flutter-import")]
    (list-dir path read-entry)))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/audio import-audio}})
