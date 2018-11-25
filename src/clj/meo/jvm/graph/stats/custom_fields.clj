(ns meo.jvm.graph.stats.custom-fields
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [clj-time.coerce :as c]
            [clj-time.format :as ctf]
            [clj-time.core :as ct]
            [meo.jvm.datetime :as dt]))

(def dtz (ct/default-time-zone))
(def fmt (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))
(defn parse [dt] (ctf/parse fmt dt))

(defn custom-fields-mapper
  "Creates mapper function for custom field stats. Takes current state. Returns
   function that takes date string, such as '2016-10-10', and returns map with
   results for the defined custom fields, plus the date string. Performs
   operation specified for field, such as sum, min, max."
  [current-state tag]
  (fn [date-string]
    (let [g (:graph current-state)
          custom-fields (:custom-fields (:cfg current-state))
          custom-field-stats-def (into {} (map (fn [[k v]] [k (:fields v)])
                                               (select-keys custom-fields [tag])))
          day-nodes (gq/get-nodes-for-day g {:date_string date-string})
          day-nodes-attrs (map #(uber/attrs g %) day-nodes)
          nodes (filter :custom_fields day-nodes-attrs)
          adjusted-ts-filter (fn [entry]
                               (let [adjusted-ts (:adjusted_ts entry)
                                     tz (:timezone entry)]
                                 (or (not adjusted-ts)
                                     (= (dt/ts-to-ymd-tz adjusted-ts tz)
                                        date-string))))
          nodes (filter adjusted-ts-filter nodes)
          stats-mapper
          (fn [[k fields]]
            (let [field-mapper
                  (fn [[field v]]
                    (let [path [:custom_fields k field]
                          val-mapper (fn [entry]
                                       (let [ts (or (:adjusted_ts entry)
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
                                    (catch Exception e (error e res)))
                               res)]))]
              (into {} (mapv field-mapper fields))))
          fields (mapv stats-mapper custom-field-stats-def)]
      (apply merge
             {:date_string date-string
              :tag         tag
              :fields      (mapv (fn [[k v]]
                                   {:field (name k)
                                    :value v})
                                 (first fields))}
             fields))))
