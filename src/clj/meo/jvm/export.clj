(ns meo.jvm.export
  (:require [taoensso.timbre :refer [info]]
            [meo.jvm.graph.query :as gq]
            [cheshire.core :as cc]
            [clojure.data.csv :as csv]
            [clojure.java.io :as io]
            [meo.jvm.file-utils :as fu]
            [clojure.string :as s]
            [progrock.core :as pr]
            [meo.jvm.datetime :as dt]
            [geo [geohash :as geohash] [spatial :as spatial]]
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

(def training-csv (str fu/export-path "/entries_stories_training.csv"))
(def test-csv (str fu/export-path "/entries_stories_test.csv"))
(def unlabeled-csv (str fu/export-path "/entries_stories_unlabeled.csv"))
(def stories-csv (str fu/export-path "/stories.csv"))
(def geohashes-csv (str fu/export-path "/geohashes.csv"))

(def h (* 60 60 1000))
(def hqd (* 3 h))
(def qd (* 6 h))
(def hd (* 12 h))
(def d (* 24 h))
(def w (* 7 d))
(def m (* 30 d))

(def features [:geohash :geohash-wide :starred :img-file :audio-file :task :md
               :weeks-ago :days-ago :quarter-day :half-quarter-day :hour
               :tags :mentions])
(def features-label (conj features :primary-story))

(defn bool2int [k x] (if (boolean (k x)) 1 0))
(defn word-count [k x] (if-let [s (k x)] (count (s/split (k x) #" ")) 0))
(defn round-geo [k x] (double (.setScale (bigdec (k x)) 3 RoundingMode/HALF_EVEN)))
(defn join [k x] (str "cat-" (or (when (seq (k x)) (str/join ";" (sort (k x)))) "0")))

(defn t-day [t]
  (fn [k x]
    (int (/ (rem (:timestamp x) d) t))))

(defn geohash [bits]
  (fn [k x]
    (let [p (spatial/spatial4j-point (:latitude x) (:longitude x))
          h (geohash/geohash p bits)]
      (geohash/string h))))

(defn t-ago [t]
  (fn [k x]
    (let [ts (:timestamp x)
          june-30-2018 1530403199000]
      (int (/ (- june-30-2018 ts) t)))))

(defn pascal [k] (s/join "" (map s/capitalize (s/split (name k) #"\-"))))

(def xforms {:task             bool2int
             :img-file         bool2int
             :audio-file       bool2int
             :md               word-count
             :days-ago         (t-ago d)
             :weeks-ago        (t-ago w)
             :months-ago       (t-ago m)
             :hour             (t-day h)
             :quarter-day      (t-day qd)
             :half-day         (t-day hd)
             :half-quarter-day (t-day hqd)
             :starred          bool2int
             :latitude         round-geo
             :longitude        round-geo
             :geohash          (geohash 40)
             :geohash-wide     (geohash 35)
             :mentions         join
             :tags             join})

(defn example-fmt [columns]
  (fn [entry]
    (mapv (fn [k]
            (let [v (k entry)]
              (if-let [xf (k xforms)]
                (xf k entry)
                v)))
          columns)))

(defn filtered-examples [entries-map]
  (let [required #{:latitude :longitude :md}
        has-required (fn [x]
                       (and (every? identity (map #(get x %) required))
                            (not (contains? (:tags x) "#habit"))))]
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
        labeled (filter :primary-story filtered)
        unlabeled (mapv (example-fmt features)
                        (filter #(not (:primary-story %)) filtered))
        stories (-> (map :primary-story labeled)
                    (set)
                    (sort)
                    (vec))
        idx-m (into {} (map-indexed (fn [idx v] [v idx]) stories))
        w-story-idx (map (fn [x] (update x :primary-story #(get idx-m %))) labeled)
        examples (shuffle (map (example-fmt features-label) w-story-idx))
        geohashes (set (map first examples))
        geo-idx-m (into {} (map-indexed (fn [idx v] [v idx]) geohashes))
        n (count examples)
        [training-data test-data] (split-at (int (* n 0.7)) examples)]
    (info "encountered" (count stories) "stories in" n "examples")
    (info (count geohashes) "geohashes")
    (write-csv training-csv (into [(mapv pascal features-label)] training-data))
    (write-csv test-csv (into [(mapv pascal features-label)] test-data))
    (write-csv unlabeled-csv (into [(mapv pascal features)] unlabeled))
    (write-csv stories-csv (mapv (fn [x] [x]) stories))
    (write-csv geohashes-csv (mapv (fn [x] [x]) geohashes))))

(defn export [msg-map]
  (time (export-geojson msg-map))
  (time (export-entry-stories msg-map))
  {})
