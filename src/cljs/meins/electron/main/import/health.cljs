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

(defn import-sleep-entry [data put-fn]
  (let [date-to (get data "date_to")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        text (str "Sleep: " value " min")
        data-type (get data "data_type")]
    (when (= data-type "sleep_asleep")
      (let [entry {:timestamp     ts
                   :md            text
                   :text          text
                   :mentions      #{}
                   :utc-offset    120
                   :timezone      "Europe/Berlin"
                   :perm_tags     #{"#sleep"}
                   :tags          #{"#sleep"}
                   :primary_story 1479889430353
                   :health_data   data
                   :custom_fields {"#sleep" {:duration value}}}]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))))

(defn convert-steps-entry [data]
  (let [date-to (get data "dateTo")
        ts (- (h/health-date-to-ts2 date-to) 123)
        value (get data "value")
        text (str "Steps: " value " total")
        data-type (get data "dataType")]
    (when (= data-type "cumulative_step_count")
      {:timestamp     ts
       :md            text
       :text          text
       :mentions      #{}
       :utc-offset    120
       :timezone      "Europe/Berlin"
       :perm_tags     #{"#steps"}
       :health_data   data
       :custom_fields {"#steps" {:cnt value}}})))

(defn import-steps-entry [data put-fn]
  (let [entry (convert-steps-entry data)]
    (when (and entry (spec/valid? :meins.entry/spec entry))
      (put-fn [:entry/save-initial entry]))))

(defn import-weight-entry [data put-fn]
  (let [date-to (get data "date_to")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        rounded-value (/ (Math/round (* value 10)) 10)
        text (str "Weight: " rounded-value " kg")
        data-type (get data "data_type")]
    (when (= data-type "weight")
      (let [entry {:timestamp     ts
                   :md            text
                   :text          text
                   :mentions      #{}
                   :utc-offset    120
                   :timezone      "Europe/Berlin"
                   :perm_tags     #{"#weight"}
                   :health_data   data
                   :custom_fields {"#weight" {:weight value}}}]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))))

(defn import-bp-entry [data put-fn]
  (let [date-to (get data "date_to")
        ts (h/health-date-to-ts date-to)
        value (get data "value")
        data-type (get data "data_type")]
    (when (= data-type "blood_pressure_systolic")
      (let [text (str "BP: " value " systolic")
            entry {:timestamp     (+ ts 1)
                   :md            text
                   :text          text
                   :mentions      #{}
                   :utc-offset    120
                   :timezone      "Europe/Berlin"
                   :perm_tags     #{"#BP"}
                   :tags          #{"#BP"}
                   :health_data   data
                   :custom_fields {"#BP" {:bp_systolic value}}}]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))
    (when (= data-type "blood_pressure_diastolic")
      (let [text (str "BP: " value " mmHg diastolic")
            entry {:timestamp     (+ ts 2)
                   :md            text
                   :text          text
                   :mentions      #{}
                   :utc-offset    120
                   :timezone      "Europe/Berlin"
                   :perm_tags     #{"#BP"}
                   :tags          #{"#BP"}
                   :health_data   data
                   :custom_fields {"#BP" {:bp_diastolic value}}}]
        (when (and entry (spec/valid? :meins.entry/spec entry))
          (put-fn [:entry/save-initial entry]))))))

(defn import-health [{:keys [msg-payload put-fn]}]
  (let [files (:files msg-payload)]
    (info "import-health:" files)
    (doseq [json-file files]
      (let [items (h/parse-json json-file)]
        (doseq [item items]
          (import-sleep-entry item put-fn)
          (import-weight-entry item put-fn)
          (import-bp-entry item put-fn)
          (import-steps-entry item put-fn))))))

(defn import-quantitative-data [path put-fn]
  (let [files (sync (str path "/**/*.quantitative.json"))]
    (doseq [json-file files]
      (let [data (h/parse-json json-file)
            item (get data "data")]
        (import-steps-entry item put-fn)))))
