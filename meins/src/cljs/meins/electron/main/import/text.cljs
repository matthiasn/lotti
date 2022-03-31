(ns meins.electron.main.import.text
  (:require ["glob" :as glob :refer [sync]]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as spec]
            ["moment" :as moment]
            [clojure.pprint :as pp]
            [expound.alpha :as exp]
            [clojure.string :as s]))

(defn convert-text-entry [json]
  (let [meta-data (get json "meta")
        date-from (get meta-data "dateFrom")
        entry-text-object (get json "entryText")
        plain-text (get entry-text-object "plainText")
        markdown (get entry-text-object "markdown")
        ts (.valueOf (moment date-from))
        geolocation (get json "geolocation")
        entry {:timestamp  ts
               :md         markdown
               :text       plain-text
               :mentions   #{}
               :utc-offset (get meta-data "utcOffset")
               :timezone   (get meta-data "timezone")
               :tags       #{}
               :perm_tags  #{}
               :longitude  (get geolocation "longitude")
               :latitude   (get geolocation "latitude")
               :vclock     (get meta-data "vectorClock")}]
    entry))

(defn import-text-entries [path put-fn]
  (let [files (sync (str path "/text_entries/**/*.text.json"))]
    (doseq [json-file files]
      (let [data (h/parse-json json-file)
            entry (convert-text-entry data)]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))))
