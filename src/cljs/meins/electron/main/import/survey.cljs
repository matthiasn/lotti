(ns meins.electron.main.import.survey
  (:require ["glob" :as glob :refer [sync]]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            ["moment" :as moment]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as spec]
            [clojure.pprint :as pp]
            [expound.alpha :as exp]
            [clojure.string :as s]))

(defn get-survey-question-value [data question-id]
  (get-in data ["taskResult" "results" question-id "results" "answer" "value"]))

(defn convert-survey-data [data]
  (let [tag "#CFQ11"
        result-map {:cfq11 {1  (get-survey-question-value data "cfq11Step1")
                            2  (get-survey-question-value data "cfq11Step2")
                            3  (get-survey-question-value data "cfq11Step3")
                            4  (get-survey-question-value data "cfq11Step4")
                            5  (get-survey-question-value data "cfq11Step5")
                            6  (get-survey-question-value data "cfq11Step6")
                            7  (get-survey-question-value data "cfq11Step7")
                            8  (get-survey-question-value data "cfq11Step8")
                            9  (get-survey-question-value data "cfq11Step9")
                            10 (get-survey-question-value data "cfq11Step10")
                            11 (get-survey-question-value data "cfq11Step11")}}]
    [tag result-map]))

(defn convert-survey [json]
  (let [meta-data (get json "meta")
        date-from (get meta-data "dateFrom")
        ts (.valueOf (moment date-from))
        data (get json "data")
        [tag survey-result] (convert-survey-data data)
        geolocation (get json "geolocation")
        entry {:geohash        (get geolocation "geohashString")
               :id             (get meta-data "id")
               :latitude       (get geolocation "latitude")
               :longitude      (get geolocation "longitude")
               :md             ""
               :mentions       #{}
               :perm_tags      #{tag}
               :questionnaires survey-result
               :tags           #{}
               :text           ""
               :timestamp      ts
               :timezone       (get meta-data "timezone")
               :utc-offset     0
               :vclock         (get meta-data "vectorClock")}]
    entry))

(defn import-filled-survey [path put-fn]
  (let [files (sync (str path "/**/*.survey.json"))]
    (doseq [json-file files]
      (when-not (s/includes? json-file "trash")
        (let [data (h/parse-json json-file)])))))
