(ns meins.jvm.graphql.geo-by-day
  (:require [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graph.query :as gq]
            [clj-time.coerce :as ctc]
            [meins.jvm.datetime :as dt]))

(def n Integer/MAX_VALUE)

(defn entry-fmt [entry]
  (let [{:keys [latitude longitude timestamp entry_type]} entry]
    (when (and latitude longitude)
      {:type       "Feature"
       :properties {:timestamp  timestamp
                    :entry_type (or entry_type :entry)}
       :geometry   {:type        "Point"
                    :coordinates [longitude latitude 0.0]}})))

(defn entry-fmt-bg-geo [entry]
  (when-let [bg-geo (:bg-geo entry)]
    (mapv
      (fn [{:keys [timestamp coords activity] :as data}]
        (let [ts (ctc/to-long timestamp)
              {:keys [longitude latitude altitude]} coords]
          {:type       "Feature"
           :properties {:timestamp  ts
                        :entry_type :bg-geo
                        :activity   (:type activity)
                        :data       (pr-str data)}
           :geometry   {:type        "Point"
                        :coordinates [longitude latitude altitude]}}))
      bg-geo)))

(defn geo-by-days
  [state _context args _value]
  (let [{:keys [from to] :as m} args
        from-ts (if from (dt/ymd-to-ts from) 0)
        to-ts (if to (+ (dt/ymd-to-ts to) (* 24 60 60 1000)) Long/MAX_VALUE)
        current-state @state
        g (:graph current-state)
        day-nodes (gq/get-nodes-for-day g {:date_string to})
        day-nodes-attrs (map #(gq/get-entry current-state %) day-nodes)
        features (filter identity (map entry-fmt day-nodes-attrs))
        features2 (flatten (filter identity (map entry-fmt-bg-geo day-nodes-attrs)))
        res (->> (concat features features2)
                 (filter #(< (-> % :properties :timestamp) to-ts))
                 (filter #(> (-> % :properties :timestamp) from-ts)))]
    res))
