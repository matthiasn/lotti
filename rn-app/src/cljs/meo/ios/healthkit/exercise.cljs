(ns meo.ios.healthkit.exercise
  (:require [meo.ios.healthkit.common :as hc]))

(defn res-cb [tag k offset put-fn err res]
  (when err (.error js/console err))
  (doseq [sample (js->clj res)]
    (let [v (get-in sample ["value"])
          end-date (get-in sample ["endDate"])
          end-ts (.valueOf (hc/moment end-date))
          v (int (/ v 60))
          entry {:timestamp     (- end-ts offset)
                 :md            (str v " minutes " tag)
                 :tags          #{tag}
                 :perm_tags     #{tag}
                 :sample        sample
                 :custom_fields {tag {k v}}}]
      (put-fn (with-meta [:entry/update entry] {:silent true}))
      (put-fn [:entry/persist entry]))))

(defn get-exercise [{:keys [msg-payload put-fn]}]
  (let [opts (clj->js {:startDate (hc/days-ago (:n msg-payload))})
        exercise-cb (partial res-cb "#exercise" :minutes 400 put-fn)
        init-cb (fn [err res]
                  (.getBasalEnergyBurned hc/health-kit opts exercise-cb))]
    (.initHealthKit hc/health-kit hc/health-kit-opts init-cb))
  {})
