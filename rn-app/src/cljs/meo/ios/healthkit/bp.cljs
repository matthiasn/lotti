(ns meo.ios.healthkit.bp
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [meo.ios.healthkit.common :as hc]
            [matthiasn.systems-toolbox.component :as st]))

(defn bp-cb [put-fn err res]
  (doseq [sample (js->clj res)]
    (let [bp-systolic (get-in sample ["bloodPressureSystolicValue"])
          bp-diastolic (get-in sample ["bloodPressureDiastolicValue"])
          end-date (get-in sample ["endDate"])
          end-ts (.valueOf (hc/moment end-date))
          bp-systolic (js/parseInt bp-systolic)
          bp-diastolic (js/parseInt bp-diastolic)
          entry {:timestamp     end-ts
                 :md            (str bp-systolic "/" bp-diastolic
                                     " mmHG #BP")
                 :tags          #{"#BP"}
                 :perm_tags     #{"#BP"}
                 :sample        sample
                 :custom_fields {"#BP" {:bp_systolic  bp-systolic
                                        :bp_diastolic bp-diastolic}}}]
      (put-fn (with-meta [:entry/update entry] {:silent true}))
      (put-fn [:entry/persist entry]))))

(defn hr-cb [tag put-fn err res]
  (doseq [sample (js->clj res)]
    (let [v (get-in sample ["value"])
          end-date (get-in sample ["endDate"])
          end-ts (.valueOf (hc/moment end-date))
          entry {:timestamp     end-ts
                 :md            (str v " bpm " tag)
                 :tags          #{tag}
                 :perm_tags     #{tag}
                 :sample        sample
                 :custom_fields {tag {:bpm v}}}]
      (put-fn (with-meta [:entry/update entry] {:silent true}))
      (put-fn [:entry/persist entry]))))

(defn blood-pressure [{:keys [put-fn msg-payload]}]
  (let [n (:n msg-payload)
        bp-opts (clj->js {:unit "mmHg" :startDate (hc/days-ago n)})
        hr-opts (clj->js {:startDate (hc/days-ago n)})
        init-cb (fn [err res]
                  (.getBloodPressureSamples hc/health-kit bp-opts (partial bp-cb put-fn))
                  (.getRestingHeartRate hc/health-kit hr-opts (partial hr-cb "#RHR" put-fn))
                  (.getWalkingHeartRateAverage hc/health-kit hr-opts (partial hr-cb "#WHR" put-fn)))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})

(defn heart-rate-variability [{:keys [put-fn msg-payload]}]
  (let [hrv-opts (clj->js {:startDate (hc/days-ago (:n msg-payload))})
        hrv-cb (fn [err res]
                 (.warn js/console res)
                 (doseq [sample (js->clj res)]
                   (let [v (get-in sample ["value"])
                         end-date (get-in sample ["endDate"])
                         end-ts (.valueOf (hc/moment end-date))
                         v (* 1000 (js/parseFloat v))
                         entry {:timestamp     end-ts
                                :md            (str (int v) "ms")
                                :tags          #{"#HRV"}
                                :perm_tags     #{"#HRV"}
                                :sample        sample
                                :custom_fields {"#HRV" {:sdnn v}}}]
                     (put-fn (with-meta [:entry/update entry] {:silent true}))
                     (put-fn [:entry/persist entry]))))
        init-cb (fn [err res]
                  (.getHeartRateVariabilitySamples hc/health-kit hrv-opts hrv-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
