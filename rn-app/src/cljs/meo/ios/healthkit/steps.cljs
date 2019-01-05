(ns meo.ios.healthkit.steps
  (:require [meo.ios.healthkit.common :as hc]
            [matthiasn.systems-toolbox.component :as st]))

(defn cb [tag k xf offset put-fn err res]
  (when err (.error js/console err))
  (doseq [sample (js->clj res)]
    (.log js/console (str sample))
    (let [v (get-in sample ["value"])
          end-date (get-in sample ["endDate"])
          end-ts (.valueOf (hc/moment end-date))
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
        init-cb (fn [err res]
                  (.getDailyStepCountSamples hc/health-kit opts steps-cb)
                  (.getDailyFlightsClimbedSamples hc/health-kit opts flights-of-stairs-cb)
                  (.getDailyDistanceWalkingRunningSamples hc/health-kit opts distance-cb)
                  (.getDailyDistanceCyclingSamples hc/health-kit opts cycling-cb))
        new-state (assoc current-state store-k now-dt)]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb)
    {:new-state new-state}))
