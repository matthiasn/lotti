(ns meo.ios.healthkit)

(enable-console-print!)

(def health-kit (js/require "rn-apple-healthkit"))
(def moment (js/require "moment"))

(def health-kit-opts
  (clj->js
    {:permissions
     {:read ["Height" "Weight" "StepCount" "BodyMassIndex" "FlightsClimbed"
             "BloodPressureDiastolic" "BloodPressureSystolic" "HeartRate"
             "DistanceWalkingRunning"]}}))

(defn get-steps [{:keys [msg-payload put-fn]}]
  (let [days-ago msg-payload
        d (js/Date.)
        _ (.setTime d (- (.getTime d) (* days-ago 24 60 60 1000)))
        opts (clj->js {:date (.toISOString d)})
        cb (fn [tag]
             (fn [err res]
               (let [res (js->clj res)
                     v (get-in res ["value"])
                     end-date (get-in res ["endDate"])]
                 (when v
                   (let [end-ts (.valueOf (moment end-date))
                         cnt (js/parseInt v)]
                     (put-fn [:entry/persist
                              {:timestamp      end-ts
                               :md             (str cnt " " tag)
                               :tags           #{tag}
                               :linked-stories #{1475314976880}
                               :primary-story  1475314976880
                               :custom-fields  {tag {:cnt cnt}}}]))))))
        init-cb (fn [err res]
                  (.getFlightsClimbed health-kit opts (cb "#flights-of-stairs"))
                  (.getStepCount health-kit opts (cb "#steps")))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn get-weight [{:keys [put-fn]}]
  (let [weight-opts (clj->js {:unit      "gram"
                              :startDate (.toISOString (js/Date. 0))})
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
                                   :custom-fields  {"#weight" {:weight kg}}
                                   :linked-stories #{1475314976880}
                                   :primary-story  1475314976880}]
                        (put-fn [:entry/persist entry]))))
        init-cb (fn [err res]
                  (.getWeightSamples health-kit weight-opts weight-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn blood-pressure [{:keys [put-fn]}]
  (let [bp-opts (clj->js {:unit      "mmHg"
                          :startDate (.toISOString (js/Date. 2016 9 1))})
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
                               :custom-fields  {"#BP" {:bp-systolic  bp-systolic
                                                       :bp-diastolic bp-diastolic}}
                               :linked-stories #{1475314976880}
                               :primary-story  1475314976880}]
                    (put-fn [:entry/persist entry]))))
        init-cb (fn [err res]
                  (.getBloodPressureSamples health-kit bp-opts bp-cb))]
    (.initHealthKit health-kit health-kit-opts init-cb))
  {})

(defn cmp-map [cmp-id]
  (.warn js/console cmp-id)
  {:cmp-id      cmp-id
   :handler-map {:healthkit/weight get-weight
                 :healthkit/steps  get-steps
                 :healthkit/bp     blood-pressure}})
