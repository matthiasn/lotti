(ns meo.ios.healthkit.steps
  (:require [meo.ios.healthkit.common :as hc]))

(defn cb [dt tag k xf put-fn err res]
  (let [sample (js->clj res)
        v (get-in sample ["value"])
        end-date (get-in sample ["endDate"])]
    (when v
      (let [end-ts (.valueOf (hc/moment end-date))
            adjusted_ts (-> (hc/moment dt)
                            (.set "hour" 23)
                            (.set "minute" 59)
                            (.set "second" 59)
                            (.set "millisecond" 747)
                            .valueOf)
            v (js/parseInt v)
            v (if xf (xf v) v)
            entry (merge
                    {:timestamp     end-ts
                     :md            (str v " " tag)
                     :tags          #{tag}
                     :perm_tags     #{tag}
                     :sample        sample
                     :custom_fields {tag {k v}}}
                    (when (> end-ts adjusted_ts)
                      {:adjusted_ts adjusted_ts}))]
        (put-fn (with-meta [:entry/update entry] {:silent true}))
        (put-fn [:entry/persist entry])))))

(defn get-steps [{:keys [msg-payload put-fn]}]
  (let [dt (hc/days-ago msg-payload)
        opts (clj->js {:date dt})
        distance-cb (partial cb dt "#DistanceWalkingRunning" :distance_walking_running #(/ % 1000) put-fn)
        cycling-cb (partial cb dt "#DistanceCycling" :distance_cycling  #(/ % 1000) put-fn)
        steps-cb (partial cb dt "#steps" :cnt nil put-fn)
        flights-of-stairs-cb (partial cb dt "#flights-of-stairs" :cnt nil put-fn)
        init-cb (fn [err res]
                  (.getStepCount hc/health-kit opts steps-cb)
                  (.getFlightsClimbed hc/health-kit opts flights-of-stairs-cb)
                  (.getDistanceWalkingRunning hc/health-kit opts distance-cb)
                  (.getDistanceCycling hc/health-kit opts cycling-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
