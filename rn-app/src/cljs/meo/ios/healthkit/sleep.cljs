(ns meo.ios.healthkit.sleep
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [meo.ios.healthkit.common :as hc]
            [matthiasn.systems-toolbox.component :as st]))

(defn get-sleep-samples [{:keys [put-fn msg-payload]}]
  (let [n (:n msg-payload)
        sleep-opts (clj->js {:startDate (hc/days-ago n)})
        sleep-cb (fn [err res]
                   (doseq [sample (js->clj res)]
                     (let [value (get-in sample ["value"])
                           tag (if (= value "ASLEEP") "#sleep" "#bed")
                           start-date (get-in sample ["startDate"])
                           start-ts (.valueOf (hc/moment start-date))
                           end-date (get-in sample ["endDate"])
                           end-ts (.valueOf (hc/moment end-date))
                           seconds (/ (- end-ts start-ts) 1000)
                           minutes (js/parseInt (/ seconds 60))
                           text (str (h/s-to-hh-mm seconds) " " tag)
                           entry {:timestamp      end-ts
                                  :sample         sample
                                  :md             text
                                  :tags           #{tag}
                                  :perm_tags      #{tag}
                                  :custom_fields  {tag {:duration minutes}}}]
                       (put-fn (with-meta [:entry/update entry] {:silent true}))
                       (put-fn [:entry/persist entry]))))
        init-cb (fn [err res] (.getSleepSamples hc/health-kit sleep-opts sleep-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
