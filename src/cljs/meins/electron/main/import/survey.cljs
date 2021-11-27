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

(defn get-survey-answer [data question-id]
  (get-in data ["taskResult" "results" question-id "results" "answer" "value"]))

(defn convert-cfq11 [data]
  ["#CFQ11"
   {:cfq11 {1  (get-survey-answer data "cfq11Step1")
            2  (get-survey-answer data "cfq11Step2")
            3  (get-survey-answer data "cfq11Step3")
            4  (get-survey-answer data "cfq11Step4")
            5  (get-survey-answer data "cfq11Step5")
            6  (get-survey-answer data "cfq11Step6")
            7  (get-survey-answer data "cfq11Step7")
            8  (get-survey-answer data "cfq11Step8")
            9  (get-survey-answer data "cfq11Step9")
            10 (get-survey-answer data "cfq11Step10")
            11 (get-survey-answer data "cfq11Step11")}}])

(defn convert-panas [data]
  ["#PANAS"
   {:panas {1  (get-survey-answer data "panasQuestion1")
            2  (get-survey-answer data "panasQuestion2")
            3  (get-survey-answer data "panasQuestion3")
            4  (get-survey-answer data "panasQuestion4")
            5  (get-survey-answer data "panasQuestion5")
            6  (get-survey-answer data "panasQuestion6")
            7  (get-survey-answer data "panasQuestion7")
            8  (get-survey-answer data "panasQuestion8")
            9  (get-survey-answer data "panasQuestion9")
            10 (get-survey-answer data "panasQuestion10")
            11 (get-survey-answer data "panasQuestion11")
            12 (get-survey-answer data "panasQuestion12")
            13 (get-survey-answer data "panasQuestion13")
            14 (get-survey-answer data "panasQuestion14")
            15 (get-survey-answer data "panasQuestion15")
            16 (get-survey-answer data "panasQuestion16")
            17 (get-survey-answer data "panasQuestion17")
            18 (get-survey-answer data "panasQuestion18")
            19 (get-survey-answer data "panasQuestion19")
            20 (get-survey-answer data "panasQuestion20")}}])

(defn convert-survey-data [data]
  (let [task-identifier (get-in data ["taskResult" "identifier"])]
    (case task-identifier
      "cfq11SurveyTask" (convert-cfq11 data)
      "panasSurveyTask" (convert-panas data))))

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
