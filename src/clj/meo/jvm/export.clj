(ns meo.jvm.export
  (:require [taoensso.timbre :refer [info]]
            [meo.jvm.graph.query :as gq]
            [cheshire.core :as cc]
            [clojure.data.csv :as csv]
            [clojure.java.io :as io]
            [meo.jvm.file-utils :as fu]))

(def path (str fu/export-path "/entries.geojson"))
(def path2 (str fu/export-path "/entries-stories.csv"))

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
  (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
        features (filter identity (map entry-fmt (vals entries-map)))
        json (cc/generate-string
               {:type     "FeatureCollection"
                :crs      {:properties {:name "urn:ogc:def:crs:OGC:1.3:CRS84"}
                           :type       "name"}
                :features features})]
    (spit path json)))

(def columns [:timestamp :latitude :longitude :primary-story
              :timezone :starred :img-file :audio-file :task])

(def xforms {:task       boolean
             :img-file   boolean
             :audio-file boolean})

(defn entry-fmt2 [entry]
  (let [{:keys [timestamp latitude longitude primary-story task
                img-file timezone starred audio-file]} entry]
    (when (and latitude longitude primary-story)
      [timestamp latitude longitude primary-story timezone starred
       (boolean img-file) (boolean audio-file) (boolean task)])))

(defn entry-fmt3 [entry]
  (mapv (fn [k]
          (let [v (k entry)]
            (if-let [xform (k xforms)]
              (xform v)
              v)))
        columns))

(defn export-entry-stories [{:keys [current-state]}]
  (info "Exporting entries with stories as CSV")
  (with-open [writer (io/writer path2)]
    (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))

          matches (filter identity (map entry-fmt2 (vals entries-map)))]
      (csv/write-csv writer (into [(mapv name columns)] matches)))))

(defn export [msg-map]
  (time (export-geojson msg-map))
  (time (export-entry-stories msg-map))
  {})
