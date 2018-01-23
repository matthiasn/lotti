(ns meo.jvm.graph.stats.custom-fields
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [clojure.tools.logging :as log]
            [clj-time.coerce :as c]
            [clj-time.format :as ctf]
            [clj-time.core :as ct]))

(def dtz (ct/default-time-zone))
(def fmt (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))
(defn parse [dt] (ctf/parse fmt dt))

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
            (let [field-mapper
                  (fn [[field v]]
                    (let [path [:custom-fields k field]
                          val-mapper (fn [entry]
                                       (let [ts (or (when-let [fd (:for-day entry)]
                                                      (c/to-long (parse fd)))
                                                    (:timestamp entry))]
                                         {:v  (get-in entry path)
                                          :ts ts}))
                          op (when (contains? #{:number :time} (:type (:cfg v)))
                               (case (:agg v)
                                 :min #(when (seq %) (apply min (map :v %)))
                                 :max #(when (seq %) (apply max (map :v %)))
                                 :mean #(when (seq %) (double (/ (apply + (map :v %)) (count %))))
                                 :sum #(apply + (map :v %))
                                 :none nil
                                 #(apply + (map :v %))))
                          res (vec (filter #(:v %) (mapv val-mapper nodes)))]
                      [field (if op
                               (try (op res)
                                    (catch Exception e (log/error e res)))
                               res)]))]
              [k (into {} (mapv field-mapper fields))]))
          day-stats (into {:date-string date-string}
                          (mapv stats-mapper custom-field-stats-def))]
      [date-string day-stats])))
