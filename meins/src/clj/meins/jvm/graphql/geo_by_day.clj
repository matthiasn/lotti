(ns meins.jvm.graphql.geo-by-day
  (:require [clj-time.coerce :as ctc]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [debug error info warn]]))

(def n Integer/MAX_VALUE)

(defn entry-fmt [entry]
  (let [{:keys [latitude longitude timestamp entry_type]} entry]
    (when (and latitude longitude)
      {:type       "Feature"
       :properties {:timestamp  timestamp
                    :entry_type (or entry_type :entry)
                    :entry      entry}
       :geometry   {:type        "Point"
                    :coordinates [longitude latitude 0.0]}})))

(defn entry-fmt-bg-geo [entry]
  (when-let [bg-geo (:bg-geo entry)]
    (mapv
      (fn [{:keys [timestamp coords activity] :as data}]
        (let [ts (ctc/to-long timestamp)
              {:keys [longitude latitude altitude accuracy]} coords]
          {:type       "Feature"
           :properties {:timestamp  ts
                        :entry_type :bg-geo
                        :activity   (:type activity)
                        :accuracy   accuracy
                        :data       (pr-str data)}
           :geometry   {:type        "Point"
                        :coordinates [longitude latitude altitude]}}))
      bg-geo)))

(defn geo-by-days
  [state _context args _value]
  (let [{:keys [from to]} args
        d (* 24 60 60 1000)
        from-ts (if from (dt/ymd-to-ts from) 0)
        to-ts (if to (+ (dt/ymd-to-ts to) d) Long/MAX_VALUE)
        current-state @state
        g (:graph current-state)
        days (map dt/ymd (range from-ts to-ts d))
        days-nodes (apply concat (map #(gq/get-nodes-for-day g {:date_string %}) days))
        day-nodes-attrs (map #(gq/get-entry current-state %) days-nodes)
        features (filter identity (map entry-fmt day-nodes-attrs))
        features2 (flatten (filter identity (map entry-fmt-bg-geo day-nodes-attrs)))
        res (->> (concat features features2)
                 (filter #(< (-> % :properties :timestamp) to-ts))
                 (filter #(> (-> % :properties :timestamp) from-ts))
                 (sort-by #(-> % :properties :timestamp)))]
    res))

(defn line-mapper [by-activity idx]
  (let [points (nth by-activity idx)
        prev-point (when (pos? idx)
                     (last (nth by-activity (dec idx))))
        point-mapper (fn [p] (->> p :geometry :coordinates (take 2) vec))
        points (if prev-point
                 (conj points prev-point)
                 points)
        activity (-> points last :properties :activity)
        coords (map point-mapper points)]
    {:type       "Feature"
     :properties {:activity activity}
     :geometry   {:type        "LineString"
                  :coordinates coords}}))

(defn geo-lines-by-days
  [state _context args _value]
  (let [{:keys [accuracy]} args
        accuracy (or accuracy 250)
        res (geo-by-days state _context args _value)
        accuracy-filter #(let [actual-accuracy (-> % :properties :accuracy)]
                           (and actual-accuracy (< actual-accuracy accuracy)))
        by-activity (->> res
                         (filter accuracy-filter)
                         (partition-by #(-> % :properties :activity))
                         (filter #(-> % first :properties :activity)))
        lines (range (count by-activity))]
    (mapv (partial line-mapper by-activity) lines)))
