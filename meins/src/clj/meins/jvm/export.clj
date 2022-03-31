(ns meins.jvm.export
  (:require [cheshire.core :as cc]
            [clj-time.coerce :as ctc]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [error info]]))

;;; Export for mapbox heatmap

(def path (str fu/export-path "/entries.geojson"))
(def n Integer/MAX_VALUE)

(defn entry-fmt [entry]
  (let [{:keys [latitude longitude timestamp]} entry]
    (when (and latitude longitude)
      {:type       "Feature"
       :properties {:timestamp timestamp}
       :geometry   {:type        "Point"
                    :coordinates [longitude latitude 0.0]}})))

(defn entry-fmt-bg-geo [entry]
  (when-let [bg-geo (:bg-geo entry)]
    (mapv
      (fn [{:keys [timestamp coords activity] :as data}]
        (let [ts (ctc/to-long timestamp)
              {:keys [longitude latitude]} coords]
          {:type       "Feature"
           :properties {:timestamp ts
                        :activity  (:type activity)
                        :data      (pr-str data)}
           :geometry   {:type        "Point"
                        :coordinates [longitude latitude 0.0]}}))
      bg-geo)))

(defn export-geojson [{:keys [current-state]}]
  (info "Exporting GeoJSON")
  (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
        features (filter identity (map entry-fmt (vals entries-map)))
        features2 (flatten (filter identity (map entry-fmt-bg-geo (vals entries-map))))
        json (cc/generate-string
               {:type     "FeatureCollection"
                :crs      {:properties {:name "urn:ogc:def:crs:OGC:1.3:CRS84"}
                           :type       "name"}
                :features (concat features features2)})]
    (spit path json)))
