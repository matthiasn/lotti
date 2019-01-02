(ns meo.ios.healthkit.weight
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [matthiasn.systems-toolbox.component :as st]
            [meo.ios.healthkit.common :as hc]))

(defn get-weight [{:keys [put-fn msg-payload]}]
  (let [n (:n msg-payload)
        weight-opts  (clj->js {:unit "gram"    :startDate (hc/days-ago n)})
        bodyfat-opts (clj->js {:unit "percent" :startDate (hc/days-ago n)})
        bmi-opts     (clj->js {:unit "count"   :startDate (hc/days-ago n)})
        weight-cb (fn [err res]
                    (doseq [sample (js->clj res)]
                      (let [v (get-in sample ["value"])
                            end-date (get-in sample ["endDate"])
                            end-ts (.valueOf (hc/moment end-date))
                            grams (js/parseInt v)
                            kg (/ grams 1000)
                            entry {:timestamp     (+ end-ts 100)
                                   :md            (str kg " #weight")
                                   :tags          #{"#weight"}
                                   :sample        sample
                                   :custom_fields {"#weight" {:weight kg}}}]
                        (put-fn (with-meta [:entry/update entry] {:silent true}))
                        (put-fn [:entry/persist entry]))))
        bodyfat-cb (fn [err res]
                     (.warn js/console "bodyfat" res)
                     (let [sample (js->clj res)
                           v (get-in sample ["value"])
                           end-date (get-in sample ["endDate"])
                           end-ts (.valueOf (hc/moment end-date))
                           entry {:timestamp     (+ end-ts 110)
                                  :md            (str v "% #body-fat")
                                  :tags          #{"#body-fat"}
                                  :perm_tags     #{"#body-fat"}
                                  :sample        sample
                                  :custom_fields {"#body-fat" {:bodyfat v}}}]
                       (put-fn (with-meta [:entry/update entry] {:silent true}))
                       (put-fn [:entry/persist entry])))
        bmi-cb (fn [err res]
                 (.warn js/console "bmi" res)
                 (let [sample (js->clj res)
                       v (get-in sample ["value"])
                       end-date (get-in sample ["endDate"])
                       end-ts (.valueOf (hc/moment end-date))
                       entry {:timestamp     (+ end-ts 120)
                              :md            (str v " #bmi")
                              :tags          #{"#bmi"}
                              :perm_tags     #{"#bmi"}
                              :sample        sample
                              :custom_fields {"#bmi" {:bmi v}}}]
                   (put-fn (with-meta [:entry/update entry] {:silent true}))
                   (put-fn [:entry/persist entry])))
        init-cb (fn [err res]
                  (.getWeightSamples hc/health-kit weight-opts weight-cb)
                  (.getLatestBodyFatPercentage hc/health-kit bodyfat-opts bodyfat-cb)
                  (.getLatestBmi hc/health-kit bmi-opts bmi-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
