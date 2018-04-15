(ns meo.jvm.export
  (:require [taoensso.timbre :refer [info]]
            [meo.jvm.graph.query :as gq]
            [cheshire.core :as cc]
            [clojure.data.csv :as csv]
            [clojure.java.io :as io]
            [meo.jvm.file-utils :as fu]
            [clojure.string :as s])
  (:import [java.math RoundingMode]))

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


;;; Export for TensorFlow

(defn write-csv [path data]
  (with-open [w (io/writer path)]
    (csv/write-csv w data)))

(def columns [:timestamp :latitude :longitude :starred :img-file
              :audio-file :task :primary-story])

(def training-csv (str fu/export-path "/entries_stories_training.csv"))
(def test-csv (str fu/export-path "/entries_stories_test.csv"))
(def stories-csv (str fu/export-path "/stories.csv"))

(defn bool2int [x] (if (boolean x) 1 0))
(defn round-geo [n] (double (.setScale (bigdec n) 4 RoundingMode/HALF_EVEN)))

(def xforms {:task       bool2int
             :img-file   bool2int
             :audio-file bool2int
             :starred    bool2int
             :latitude   round-geo
             :longitude  round-geo})

(defn example-fmt [entry]
  (mapv (fn [k]
          (let [v (k entry)]
            (if-let [xf (k xforms)]
              (xf v)
              v)))
        columns))

(defn pascal [k] (s/join "" (map s/capitalize (s/split (name k) #"\-"))))

(defn filtered-examples [entries-map]
  (let [required #{:latitude :longitude :primary-story}
        has-required (fn [x] (every? identity (map #(get x %) required)))]
    (filter has-required (vals entries-map))))

(defn export-entry-stories [{:keys [current-state]}]
  (info "CSV export: entries with stories")
  (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
        examples (shuffle (map example-fmt (filtered-examples entries-map)))
        n (count examples)
        stories (set (map last examples))
        [training-data test-data] (split-at (int (* n 0.8)) examples)]
    (info "encountered" (count stories) "stories in" n "examples")
    (write-csv training-csv (into [(mapv pascal columns)] training-data))
    (write-csv test-csv (into [(mapv pascal columns)] test-data))
    (write-csv stories-csv [(vec stories)])))

(defn export [msg-map]
  (time (export-geojson msg-map))
  (time (export-entry-stories msg-map))
  {})
