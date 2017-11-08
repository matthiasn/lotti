(ns meo.jvm.graph.stats.custom-fields
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [clj-time.core :as t]
            [meo.jvm.graph.stats.awards :as aw]
            [meo.jvm.graph.stats.time :as t-s]
            [meo.common.utils.misc :as u]
            [clj-time.format :as ctf]
            [matthiasn.systems-toolbox.log :as l]
            [clojure.tools.logging :as log]
            [ubergraph.core :as uc]))

(defn custom-fields-mapper
  "Creates mapper function for custom field stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   results for the defined custom fields, plus the date string. Performs
   operation specified for field, such as sum, min, max."
  [current-state]
  (fn [d]
    (let [g (:graph current-state)
          custom-fields (:custom-fields (:cfg current-state))
          custom-field-stats-def (into {} (map (fn [[k v]] [k (:fields v)])
                                               custom-fields))
          date-string (:date-string d)
          day-nodes (gq/get-nodes-for-day g {:date-string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          nodes (filter :custom-fields day-nodes-attrs)
          for-day-filter (fn [entry]
                           (let [for-day (:for-day entry)]
                             (or (not for-day)
                                 (= date-string (subs for-day 0 10)))))
          nodes (filter for-day-filter nodes)

          stats-mapper
          (fn [[k fields]]
            (let [sum-mapper
                  (fn [[field v]]
                    (let [path [:custom-fields k field]
                          val-mapper #(get-in % path)
                          op (if (contains? #{:number :time} (:type (:cfg v)))
                               (case (:agg v)
                                 :min #(when (seq %) (apply min %))
                                 :max #(when (seq %) (apply max %))
                                 :mean #(when (seq %) (double (/ (apply + %) (count %))))
                                 :none nil
                                 #(apply + %))
                               nil)
                          res (mapv val-mapper nodes)]
                      [field (when op
                               (try (op (filter identity res))
                                    (catch Exception e (log/error e res))))]))]
              [k (into {} (mapv sum-mapper fields))]))
          day-stats (into {:date-string date-string}
                          (mapv stats-mapper custom-field-stats-def))]
      [date-string day-stats])))
