(ns meo.ios.healthkit
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
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
  (let [opts (clj->js {:date (days-ago (inc msg-payload))})
        cb (fn [tag]
             (fn [err res]
               (let [sample (js->clj res)
                     v (get-in sample ["value"])
                     end-date (get-in sample ["endDate"])]
                 (when v
                   (let [end-ts (- (.valueOf (moment end-date))
                                   (* 30 60 1000))
                         cnt (js/parseInt v)
                         entry {:timestamp      end-ts
                                :md             (str cnt " " tag)
                                :tags           #{tag}
                                :sample         sample
                                :linked-stories #{1475314976880}
                                :primary-story  1475314976880
                                :custom-fields  {tag {:cnt cnt}}}]
                     (put-fn [:entry/persist entry])
                     (put-fn [:entry/update entry]))))))
        init-cb (fn [err res]
                  (.getFlightsClimbed health-kit opts (cb "#flights-of-stairs"))
                  (.getStepCount health-kit opts (cb "#steps")))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn get-weight [{:keys [put-fn]}]
  (let [weight-opts (clj->js {:unit      "gram"
                              :startDate (days-ago 21)})
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
                                   :custom-fields  {"#weight" {:weight kg}}
                                   :linked-stories #{1475314976880}
                                   :primary-story  1475314976880}]
                        (put-fn [:entry/persist entry])
                        (put-fn [:entry/update entry]))))
        init-cb (fn [err res]
                  (.getWeightSamples health-kit weight-opts weight-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn blood-pressure [{:keys [put-fn]}]
  (let [bp-opts (clj->js {:unit      "mmHg"
                          :startDate (days-ago 21)})
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
                               :custom-fields  {"#BP" {:bp-systolic  bp-systolic
                                                       :bp-diastolic bp-diastolic}}
                               :linked-stories #{1475314976880}
                               :primary-story  1475314976880}]
                    (put-fn [:entry/persist entry])
                    (put-fn [:entry/update entry]))))
        init-cb (fn [err res]
                  (.getBloodPressureSamples health-kit bp-opts bp-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn get-sleep-samples [{:keys [put-fn]}]
  (let [sleep-opts (clj->js {:startDate (days-ago 21)})
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
                           text (str (um/duration-string seconds) " " tag)
                           entry {:timestamp      end-ts
                                  :sample         sample
                                  :md             text
                                  :tags           #{tag}
                                  :custom-fields  {tag {:duration minutes}}
                                  :linked-stories #{1479889430353}
                                  :primary-story  1479889430353}]
                       (put-fn [:entry/persist entry])
                       (put-fn [:entry/update entry]))))
        init-cb (fn [err res] (.getSleepSamples health-kit sleep-opts sleep-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:healthkit/weight get-weight
                 :healthkit/steps  get-steps
                 :healthkit/sleep  get-sleep-samples
                 :healthkit/bp     blood-pressure}})
