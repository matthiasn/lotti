(ns meins.electron.main.import.health
  (:require ["glob" :as glob :refer [sync]]
            ["fs" :refer [copyFileSync existsSync readFileSync]]
            [taoensso.timbre :refer [error info]]
            [clojure.string :as str]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as spec]
            ["child_process" :refer [spawn]]
            [clojure.pprint :as pp]
            [expound.alpha :as exp]
            [clojure.string :as s]))

(defn convert-sleep-entry [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        text (str "Sleep: " value " min")
        data-type (get data "dataType")]
    (when (= data-type "HealthDataType.SLEEP_ASLEEP")
      {:timestamp     ts
       :md            text
       :text          text
       :mentions      #{}
       :utc-offset    (get meta-data "utcOffset")
       :timezone      (get meta-data "timezone")
       :perm_tags     #{"#sleep"}
       :tags          #{"#sleep"}
       :primary_story 1479889430353
       :health_data   data
       :custom_fields {"#sleep" {:duration value}}})))

(defn convert-steps-entry [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (- (h/health-date-to-ts2 date-to) 123)
        value (get data "value")
        text (str "Steps: " value " total")
        data-type (get data "dataType")]
    (when (= data-type "cumulative_step_count")
      {:timestamp     ts
       :md            text
       :text          text
       :mentions      #{}
       :utc-offset    (get meta-data "utcOffset")
       :timezone      (get meta-data "timezone")
       :perm_tags     #{"#steps"}
       :health_data   data
       :custom_fields {"#steps" {:cnt value}}})))

(defn convert-weight-entry [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        rounded-value (/ (Math/round (* value 10)) 10)
        text (str "Weight: " rounded-value " kg")
        data-type (get data "dataType")]
    (when (= data-type "HealthDataType.WEIGHT")
      {:timestamp     ts
       :md            text
       :text          text
       :mentions      #{}
       :utc-offset    (get meta-data "utcOffset")
       :timezone      (get meta-data "timezone")
       :perm_tags     #{"#weight"}
       :health_data   data
       :custom_fields {"#weight" {:weight value}}})))

(defn convert-bodyfat-entry [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        rounded-value (/ (Math/round (* value 1000)) 10)
        text (str "Body fat: " rounded-value "%")
        data-type (get data "dataType")]
    (when (= data-type "HealthDataType.BODY_FAT_PERCENTAGE")
      {:timestamp     ts
       :md            text
       :text          text
       :mentions      #{}
       :utc-offset    (get meta-data "utcOffset")
       :timezone      (get meta-data "timezone")
       :perm_tags     #{"#body-fat"}
       :health_data   data
       :custom_fields {"#body-fat" {:bodyfat rounded-value}}})))

(defn convert-bp-entry-systolic [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        data-type (get data "dataType")]
    (when (= data-type "HealthDataType.BLOOD_PRESSURE_SYSTOLIC")
      (let [text (str "BP: " value " mmHg systolic")]
        {:timestamp     (+ ts 1)
         :md            text
         :text          text
         :mentions      #{}
         :utc-offset    (get meta-data "utcOffset")
         :timezone      (get meta-data "timezone")
         :perm_tags     #{"#BP"}
         :tags          #{"#BP"}
         :health_data   data
         :custom_fields {"#BP" {:bp_systolic value}}}))))

(defn convert-bp-entry-diastolic [item]
  (let [data (get item "data")
        meta-data (get item "meta")
        date-to (get data "dateTo")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        data-type (get data "dataType")]
    (when (= data-type "HealthDataType.BLOOD_PRESSURE_DIASTOLIC")
      (let [text (str "BP: " value " mmHg diastolic")]
        {:timestamp     (+ ts 2)
         :md            text
         :text          text
         :mentions      #{}
         :utc-offset    (get meta-data "utcOffset")
         :timezone      (get meta-data "timezone")
         :perm_tags     #{"#BP"}
         :tags          #{"#BP"}
         :health_data   data
         :custom_fields {"#BP" {:bp_diastolic value}}}))))

(defn import-entry [item convert-fn put-fn]
  (let [entry (convert-fn item)]
    (when (and entry (spec/valid? :meins.entry/spec entry))
      (put-fn [:entry/save-initial entry]))))

(defn import-quantitative-data [path put-fn]
  (let [files (sync (str path "/**/*.quantitative.json"))]
    (doseq [json-file files]
      (let [item (h/parse-json json-file)]
        (import-entry item convert-sleep-entry put-fn)
        (import-entry item convert-weight-entry put-fn)
        (import-entry item convert-bodyfat-entry put-fn)
        (import-entry item convert-bp-entry-systolic put-fn)
        (import-entry item convert-bp-entry-diastolic put-fn)
        (import-entry item convert-steps-entry put-fn)))))
