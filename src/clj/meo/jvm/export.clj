(ns meo.jvm.export
  (:require [taoensso.timbre :refer [info]]
            [meo.jvm.graph.query :as gq]
            [cheshire.core :as cc]
            [meo.jvm.file-utils :as fu]))

(def path (str fu/export-path "/entries.geojson"))
(def n Integer/MAX_VALUE)

(defn entry-fmt [entry]
  (let [{:keys [latitude longitude timestamp]} entry]
    (when (and latitude longitude)
      {:type       "Feature"
       :properties {:timestamp timestamp}
       :geometry   {:type        "Point"
                    :coordinates [longitude latitude 0.0]}})))

(defn export-geojson [{:keys [current-state]}]
  (info "Exporting GeoJSON")
  (time
    (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
          features (filter identity (map entry-fmt (vals entries-map)))
          json (cc/generate-string
                 {:type     "FeatureCollection"
                  :crs      {:properties {:name "urn:ogc:def:crs:OGC:1.3:CRS84"}
                             :type       "name"}
                  :features features})]
      (spit path json)))
  {})
