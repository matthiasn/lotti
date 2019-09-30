(ns meins.components.healthkit.steps
  (:require ["@matthiasn/rn-apple-healthkit" :as hk]
            ["moment" :as moment]
            [matthiasn.systems-toolbox.component :as st]
            [meins.components.healthkit.common :as hc]))

(defn cb [tag k xf offset put-fn err res]
  (when err (js/console.error err))
  (doseq [sample (js->clj res)]
    (.log js/console (str sample))
    (let [v (get-in sample ["value"])
          end-date (get-in sample ["endDate"])
          end-ts (.valueOf (moment end-date))
          v (int v)
          v (if xf (xf v) v)
          entry {:timestamp     (- end-ts offset)
                 :md            (str v " " tag)
                 :tags          #{tag}
                 :perm_tags     #{tag}
                 :hidden        true
                 :sample        sample
                 :custom_fields {tag {k v}}}]
      (put-fn (with-meta [:entry/update entry] {:silent true}))
      (put-fn [:entry/persist entry]))))

(defn get-steps [{:keys [msg-payload put-fn current-state]}]
  (let [store-k :last-read-steps
        start (or (store-k current-state)
                  (hc/days-ago (:n msg-payload)))
        opts (clj->js {:startDate start})
        now-dt (hc/date-from-ts (st/now))
        distance-cb (partial cb "#DistanceWalkingRunning" :distance_walking_running #(/ % 1000) 10 put-fn)
        cycling-cb (partial cb "#DistanceCycling" :distance_cycling #(/ % 1000) 20 put-fn)
        steps-cb (partial cb "#steps" :cnt nil 30 put-fn)
        flights-of-stairs-cb (partial cb "#flights-of-stairs" :cnt nil 40 put-fn)
        init-cb (fn [_err _res]
                  (.getDailyStepCountSamples hk opts steps-cb)
                  (.getDailyFlightsClimbedSamples hk opts flights-of-stairs-cb)
                  (.getDailyDistanceWalkingRunningSamples hk opts distance-cb)
                  (.getDailyDistanceCyclingSamples hk opts cycling-cb))
        new-state (assoc current-state store-k now-dt)]
    (.initHealthKit hk hc/hk-opts init-cb)
    {:new-state new-state}))
