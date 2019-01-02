(ns meo.ios.healthkit.bp
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [meo.ios.healthkit.common :as hc]
            [matthiasn.systems-toolbox.component :as st]))

(defn blood-pressure [{:keys [put-fn msg-payload]}]
  (let [n (:n msg-payload)
        bp-opts (clj->js {:unit      "mmHg"
                          :startDate (hc/days-ago n)})
        bp-cb (fn [err res]
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
        init-cb (fn [err res]
                  (.getBloodPressureSamples hc/health-kit bp-opts bp-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})

(defn heart-rate-variability [{:keys [put-fn msg-payload]}]
  (let [hrv-opts (clj->js {:startDate (hc/days-ago (:n msg-payload))})
        hrv-cb (fn [err res] (.warn js/console res))
        init-cb (fn [err res]
                  (.getHeartRateVariabilitySamples hc/health-kit hrv-opts hrv-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
