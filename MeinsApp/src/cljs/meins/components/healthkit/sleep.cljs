(ns meins.components.healthkit.sleep
  (:require ["@matthiasn/rn-apple-healthkit" :as hk]
            ["moment" :as moment]
            [matthiasn.systems-toolbox.component :as st]
            [meins.components.healthkit.common :as hc]
            [meins.helpers :as h]))

(defn get-sleep-samples [{:keys [put-fn msg-payload current-state]}]
  (let [start (or (:last-read-sleep current-state)
                  (hc/days-ago (:n msg-payload)))
        sleep-opts (clj->js {:startDate start})
        now-dt (hc/date-from-ts (st/now))
        sleep-cb (fn [_err res]
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
                           entry {:timestamp     end-ts
                                  :sample        sample
                                  :md            text
                                  :tags          #{tag}
                                  :perm_tags     #{tag}
                                  :custom_fields {tag {:duration minutes}}}]
                       (put-fn (with-meta [:entry/update entry] {:silent true}))
                       (put-fn [:entry/persist entry]))))
        init-cb (fn [_err _res] (.getSleepSamples hk sleep-opts sleep-cb))
        new-state (assoc current-state :last-read-sleep now-dt)]
    (.initHealthKit hk hc/hk-opts init-cb)
    {:new-state new-state}))
