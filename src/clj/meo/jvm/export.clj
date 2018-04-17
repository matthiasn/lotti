(ns meo.jvm.export
  (:require [taoensso.timbre :refer [info]]
            [meo.jvm.graph.query :as gq]
            [cheshire.core :as cc]
            [clojure.data.csv :as csv]
            [clojure.java.io :as io]
            [meo.jvm.file-utils :as fu]
            [clojure.string :as s]
            [meo.jvm.datetime :as dt]
            [geo [geohash :as geohash] [jts :as jts] [spatial :as spatial] [io :as gio]]
            [matthiasn.systems-toolbox.component :as st]
            [clojure.string :as str]
            [clojure.set :as set])
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

(def columns [:geohash :starred :img-file :audio-file :task
              :md :day :hour :tags :mentions :primary-story])

(def training-csv (str fu/export-path "/entries_stories_training.csv"))
(def test-csv (str fu/export-path "/entries_stories_test.csv"))
(def stories-csv (str fu/export-path "/stories.csv"))
(def geohashes-csv (str fu/export-path "/geohashes.csv"))

(def h (* 60 60 1000))
(def d (* 24 h))

(defn bool2int [k x] (if (boolean (k x)) 1 0))
(defn word-count [k x] (count (s/split (k x) #" ")))
(defn round-geo [k x] (double (.setScale (bigdec (k x)) 3 RoundingMode/HALF_EVEN)))
(defn hour [k x] (int (/ (rem (:timestamp x) d) h)))
(defn join [k x] (str (name k) "-" (or (when (seq (k x)) (str/join ";" (sort (k x)))) "0")))

(defn geohash [bits]
  (fn [k x]
    (let [p (spatial/spatial4j-point (:latitude x) (:longitude x))
          h (geohash/geohash p bits)]
      (geohash/string h))))

(defn days-ago [k x]
  (let [ts (:timestamp x)
        now (st/now)]
    (int (/ (- now ts) d))))

(defn pascal [k] (s/join "" (map s/capitalize (s/split (name k) #"\-"))))

(def xforms {:task       bool2int
             :img-file   bool2int
             :audio-file bool2int
             :md         word-count
             :day        days-ago
             :hour       hour
             :starred    bool2int
             :latitude   round-geo
             :longitude  round-geo
             :geohash    (geohash 35)
             :mentions   join
             :tags       join})

(defn example-fmt [entry]
  (mapv (fn [k]
          (let [v (k entry)]
            (if-let [xf (k xforms)]
              (xf k entry)
              v)))
        columns))

(defn filtered-examples [entries-map]
  (let [required #{:latitude :longitude :primary-story}
        has-required (fn [x] (every? identity (map #(get x %) required)))]
    (filter has-required (vals entries-map))))

(defn dict [k xs]
  (let [sets (map #(set (k %)) xs)
        words (apply set/union sets)]
    (into {} (map-indexed (fn [idx v] [v idx]) words))))

(defn replace-w-idx [k dic]
  (fn [x]
    (update-in x [k] (fn [ts] (set (map (fn [t] (get dic t 0)) ts))))))

(defn export-entry-stories [{:keys [current-state]}]
  (info "CSV export: entries with stories")
  (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
        filtered (filtered-examples entries-map)
        tags-dict (dict :tags filtered)
        mentions-dict (dict :mentions filtered)
        tags-idxr (replace-w-idx :tags tags-dict)
        mentions-idxr (replace-w-idx :mentions mentions-dict)
        filtered (->> filtered
                     (map tags-idxr)
                     (map mentions-idxr))
        stories (-> (map :primary-story filtered)
                    (set)
                    (sort)
                    (vec))
        idx-m (into {} (map-indexed (fn [idx v] [v idx]) stories))
        w-story-idx (map (fn [x] (update x :primary-story #(get idx-m %))) filtered)
        examples (shuffle (map example-fmt w-story-idx))
        geohashes (set (map first examples))
        geo-idx-m (into {} (map-indexed (fn [idx v] [v idx]) geohashes))
        n (count examples)
        [training-data test-data] (split-at (int (* n 0.8)) examples)]
    (info "encountered" (count stories) "stories in" n "examples")
    (info (count geohashes) "geohashes")
    (write-csv training-csv (into [(mapv pascal columns)] training-data))
    (write-csv test-csv (into [(mapv pascal columns)] test-data))
    (write-csv stories-csv (mapv (fn [x] [x]) stories))
    (write-csv geohashes-csv (mapv (fn [x] [x]) geohashes))))

(defn export [msg-map]
  (time (export-geojson msg-map))
  (time (export-entry-stories msg-map))
  {})
