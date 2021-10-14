(ns meins.electron.main.import
  (:require ["glob" :as glob :refer [sync]]
            ["fs" :refer [existsSync readFileSync]]
            [taoensso.timbre :refer [error info]]))

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

(defn list-dir [path]
  (let [files (sync (str path "/**/*.json"))]
    (doseq [file files]
      (let [entry (read-entry file)]
        (info entry)))))
