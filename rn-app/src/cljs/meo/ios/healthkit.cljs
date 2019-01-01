(ns meo.ios.healthkit
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [matthiasn.systems-toolbox.component :as st]))

(enable-console-print!)

(def health-kit (js/require "rn-apple-healthkit"))
(def moment (js/require "moment"))

(defn days-ago [n]
  (let [offset (* n 24 60 60 1000)
        date (js/Date. (- (st/now) offset))]
    (.toISOString date)))

(def health-kit-opts
  (clj->js
    {:permissions
     {:read ["Height" "Weight" "StepCount" "BodyMassIndex" "FlightsClimbed"
             "BloodPressureDiastolic" "BloodPressureSystolic" "HeartRate"
             "DistanceWalkingRunning" "SleepAnalysis" "RespiratoryRate"]}}))

(defn get-steps [{:keys [msg-payload put-fn]}]
  (let [dt (days-ago msg-payload)
        opts (clj->js {:date dt})
        cb (fn [tag]
             (fn [err res]
               (let [sample (js->clj res)
                     v (get-in sample ["value"])
                     end-date (get-in sample ["endDate"])]
                 (when v
                   (let [end-ts (.valueOf (moment end-date))
                         adjusted_ts (-> (moment dt)
                                         (.set "hour" 23)
                                         (.set "minute" 59)
                                         (.set "second" 59)
                                         (.set "millisecond" 747)
                                         .valueOf)
                         cnt (js/parseInt v)
                         entry (merge
                                 {:timestamp     end-ts
                                  :md            (str cnt " " tag)
                                  :tags          #{tag}
                                  :perm_tags     #{tag}
                                  :sample        sample
                                  :custom_fields {tag {:cnt cnt}}}
                                 (when (> end-ts adjusted_ts)
                                   {:adjusted_ts adjusted_ts}))]
                     (put-fn (with-meta [:entry/update entry] {:silent true}))
                     (put-fn [:entry/persist entry]))))))
        init-cb (fn [err res]
                  (.getFlightsClimbed health-kit opts (cb "#flights-of-stairs"))
                  (.getStepCount health-kit opts (cb "#steps")))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn get-weight [{:keys [put-fn]}]
  (let [weight-opts (clj->js {:unit      "gram"
                              :startDate (days-ago 7)})
        weight-cb (fn [err res]
                    (doseq [sample (js->clj res)]
                      (let [v (get-in sample ["value"])
                            end-date (get-in sample ["endDate"])
                            end-ts (.valueOf (moment end-date))
                            grams (js/parseInt v)
                            kg (/ grams 1000)
                            entry {:timestamp      end-ts
                                   :md             (str kg " #weight")
                                   :tags           #{"#weight"}
                                   :sample         sample
                                   :custom_fields  {"#weight" {:weight kg}}
                                   :linked_stories #{1475314976880}
                                   :primary_story  1475314976880}]
                        (put-fn (with-meta [:entry/update entry] {:silent true}))
                        (put-fn [:entry/persist entry]))))
        init-cb (fn [err res]
                  (.getWeightSamples health-kit weight-opts weight-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn blood-pressure [{:keys [put-fn]}]
  (let [bp-opts (clj->js {:unit      "mmHg"
                          :startDate (days-ago 7)})
        bp-cb (fn [err res]
                (doseq [sample (js->clj res)]
                  (let [bp-systolic (get-in sample ["bloodPressureSystolicValue"])
                        bp-diastolic (get-in sample ["bloodPressureDiastolicValue"])
                        end-date (get-in sample ["endDate"])
                        end-ts (.valueOf (moment end-date))
                        bp-systolic (js/parseInt bp-systolic)
                        bp-diastolic (js/parseInt bp-diastolic)
                        entry {:timestamp      end-ts
                               :md             (str bp-systolic "/" bp-diastolic
                                                    " mmHG #BP")
                               :tags           #{"#BP"}
                               :sample         sample
                               :custom_fields  {"#BP" {:bp_systolic  bp-systolic
                                                       :bp_diastolic bp-diastolic}}
                               :linked_stories #{1475314976880}
                               :primary_story  1475314976880}]
                    (put-fn (with-meta [:entry/update entry] {:silent true}))
                    (put-fn [:entry/persist entry]))))
        init-cb (fn [err res]
                  (.getBloodPressureSamples health-kit bp-opts bp-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn get-sleep-samples [{:keys [put-fn]}]
  (let [sleep-opts (clj->js {:startDate (days-ago 7)})
        sleep-cb (fn [err res]
                   (doseq [sample (js->clj res)]
                     (let [value (get-in sample ["value"])
                           tag (if (= value "ASLEEP") "#sleep" "#bed")
                           start-date (get-in sample ["startDate"])
                           start-ts (.valueOf (moment start-date))
                           end-date (get-in sample ["endDate"])
                           end-ts (.valueOf (moment end-date))
                           seconds (/ (- end-ts start-ts) 1000)
                           minutes (js/parseInt (/ seconds 60))
                           text (str (h/s-to-hh-mm seconds) " " tag)
                           entry {:timestamp      end-ts
                                  :sample         sample
                                  :md             text
                                  :tags           #{tag}
                                  :custom_fields  {tag {:duration minutes}}
                                  :linked_stories #{1479889430353}
                                  :primary_story  1479889430353}]
                       (put-fn (with-meta [:entry/update entry] {:silent true}))
                       (put-fn [:entry/persist entry]))))
        init-cb (fn [err res] (.getSleepSamples health-kit sleep-opts sleep-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:healthkit/weight get-weight
                 :healthkit/steps  get-steps
                 :healthkit/sleep  get-sleep-samples
                 :healthkit/bp     blood-pressure}})
