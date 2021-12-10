(ns meins.electron.main.import.measurement
  (:require ["glob" :as glob :refer [sync]]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as spec]
            ["moment" :as moment]
            [clojure.pprint :as pp]
            [expound.alpha :as exp]
            [clojure.string :as s]))

(defn convert-measurement-entry [json]
  (let [meta-data (get json "meta")
        date-from (get meta-data "dateFrom")
        ts (.valueOf (moment date-from))
        geolocation (get json "geolocation")
        data (get json "data")
        data-type (get data "dataType")
        value (get data "value")
        tag (str "#" (get data-type "name"))
        unit (get data-type "unitName")
        plain-text (str value " " unit " " tag)
        entry {:timestamp        ts
               :measurement_data {:id (get meta-data "id")}
               :md               plain-text
               :text             plain-text
               :mentions         #{}
               :custom_fields    {tag {:vol value}},
               :utc-offset       (get meta-data "utcOffset")
               :timezone         (get meta-data "timezone")
               :perm_tags        #{tag}
               :tags             #{tag}
               :longitude        (get geolocation "longitude")
               :latitude         (get geolocation "latitude")
               :vclock           (get meta-data "vectorClock")}]
    entry))

(defn import-measurement-entries [path put-fn]
  (let [files (sync (str path "/measurement/**/*.measurement.json"))]
    (doseq [json-file files]
      (let [data (h/parse-json json-file)
            entry (convert-measurement-entry data)]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))))
