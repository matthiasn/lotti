(ns meins.components.healthkit.weight
  (:require ["@matthiasn/rn-apple-healthkit" :as hk]
            ["moment" :as moment]
            [matthiasn.systems-toolbox.component :as st]
            [meins.components.healthkit.common :as hc]
            [cljs.pprint :as pp]))

(defn round [n d]
  (let [fmt (str "~," d "f")]
    (js/parseFloat (pp/cl-format nil fmt n))))

(defn get-weight [{:keys [put-fn msg-payload current-state]}]
  (let [start (or (:last-read-weight current-state)
                  (hc/days-ago (:n msg-payload)))
        weight-opts (clj->js {:unit "gram" :startDate start})
        bodyfat-opts (clj->js {:unit "percent" :startDate start})
        bmi-opts (clj->js {:unit "count" :startDate start})
        now-dt (hc/date-from-ts (st/now))
        weight-cb (fn [_err res]
                    (doseq [sample (js->clj res)]
                      (let [v (get-in sample ["value"])
                            end-date (get-in sample ["endDate"])
                            end-ts (.valueOf (moment end-date))
                            grams (js/parseInt v)
                            kg (round (/ grams 1000) 1)
                            entry {:timestamp     (+ end-ts 100)
                                   :md            (str kg " #weight")
                                   :tags          #{"#weight"}
                                   :sample        sample
                                   :custom_fields {"#weight" {:weight kg}}}]
                        (put-fn (with-meta [:entry/update entry] {:silent true}))
                        (put-fn [:entry/persist entry]))))
        bodyfat-cb (fn [_err res]
                     (.warn js/console "bodyfat" res)
                     (let [sample (js->clj res)
                           v (get-in sample ["value"])
                           v (round v 1)
                           end-date (get-in sample ["endDate"])
                           end-ts (.valueOf (moment end-date))
                           entry {:timestamp     (+ end-ts 110)
                                  :md            (str v "% #body-fat")
                                  :tags          #{"#body-fat"}
                                  :perm_tags     #{"#body-fat"}
                                  :sample        sample
                                  :custom_fields {"#body-fat" {:bodyfat v}}}]
                       (put-fn (with-meta [:entry/update entry] {:silent true}))
                       (put-fn [:entry/persist entry])))
        bmi-cb (fn [_err res]
                 (.warn js/console "bmi" res)
                 (let [sample (js->clj res)
                       v (get-in sample ["value"])
                       end-date (get-in sample ["endDate"])
                       end-ts (.valueOf (moment end-date))
                       v (round v 1)
                       entry {:timestamp     (+ end-ts 120)
                              :md            (str v " #bmi")
                              :tags          #{"#bmi"}
                              :perm_tags     #{"#bmi"}
                              :sample        sample
                              :custom_fields {"#bmi" {:bmi v}}}]
                   (put-fn (with-meta [:entry/update entry] {:silent true}))
                   (put-fn [:entry/persist entry])))
        init-cb (fn [_err _res]
                  (.getWeightSamples hk weight-opts weight-cb)
                  (.getLatestBodyFatPercentage hk bodyfat-opts bodyfat-cb)
                  (.getLatestBmi hk bmi-opts bmi-cb))
        new-state (assoc current-state :last-read-weight now-dt)]
    (.initHealthKit hk hc/hk-opts init-cb)
    {:new-state new-state}))
