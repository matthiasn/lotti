(ns meins.jvm.learn
  (:require [clojure.data.csv :as csv]
            [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.set :as set]
            [clojure.string :as s]
            [me.raynes.conch :refer [let-programs]]
            [me.raynes.fs :as fs]
            [meins.jvm.file-utils :as fu]
    ;[geo [geohash :as geohash] [spatial :as spatial]]
            [meins.jvm.graph.query :as gq]
            [taoensso.timbre :refer [error info]])
  (:import [java.math RoundingMode]))

(def n Integer/MAX_VALUE)

;;; Export for TensorFlow

(defn write-csv [path data]
  (with-open [w (io/writer path)]
    (csv/write-csv w data)))

(def training-csv (str fu/export-path "/entries_stories_training.csv"))
(def test-csv (str fu/export-path "/entries_stories_test.csv"))
(def unlabeled-csv (str fu/export-path "/entries_stories_unlabeled.csv"))
(def predictions-csv (str fu/export-path "/entries_stories_predictions.csv"))
(def stories-csv (str fu/export-path "/stories.csv"))
(def geohashes-csv (str fu/export-path "/geohashes.csv"))

(def h (* 60 60 1000))
(def hqd (* 3 h))
(def qd (* 6 h))
(def hd (* 12 h))
(def d (* 24 h))
(def w (* 7 d))
(def m (* 30 d))

(def features [:timestamp :geohash40 :geohash35 :geohash30 :geohash25 :geohash20
               :geohash15 :visit :starred :img_file
               :audio-file :task :screenshot :md :weeks-ago :days-ago
               :quarter-day :half-quarter-day :hour :tags1 :mentions1])
(def features-label (conj features :primary-story))

(defn bool2int
  [k x]
  (if (boolean (k x)) 1 0))

(defn word-count
  [k x]
  (if (k x) (count (s/split (k x) #" ")) 0))

(defn round-geo
  [k x]
  (double (.setScale (bigdec (k x)) 3 RoundingMode/HALF_EVEN)))

(defn join
  [k x]
  (or (when (seq (k x)) (s/join "|" (sort (k x)))) "0"))

(defn has-tag?
  [t]
  (fn
    [_k x]
    (if (contains? (set (:tags x)) t) 1 0)))

(defn t-day [t]
  (fn [_k x]
    (int (/ (rem (:timestamp x) d) t))))
#_
(defn geohash [bits]
  (fn [k x]
    (let [p (spatial/spatial4j-point (:latitude x) (:longitude x))
          h (geohash/geohash p bits)]
      (geohash/string h))))

(defn t-ago [t]
  (fn [_k x]
    (let [ts (:timestamp x)
          june-30-2018 1530403199000]
      (int (/ (- june-30-2018 ts) t)))))

(defn pascal [k] (s/join "" (map s/capitalize (s/split (name k) #"\-"))))

(def xforms {:task             bool2int
             :img_file         bool2int
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
             :visit            (has-tag? "#visit")
             :screenshot       (has-tag? "#screenshot")
             ;:geohash40        (geohash 40)
             ;:geohash35        (geohash 35)
             ;:geohash30        (geohash 30)
             ;:geohash25        (geohash 25)
             ;:geohash20        (geohash 20)
             ;:geohash15        (geohash 15)
             :mentions1        join
             :tags1            join})

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
                            (not (contains? (:tags x) "#habit"))
                            (not (contains? (:tags x) "#briefing"))
                            (not (= (:entry_type x) :story))
                            (not (= (:entry_type x) :saga))
                            (not (:comment_for x))))]
    (filter has-required (vals entries-map))))

(defn dict [k xs]
  (let [sets (map #(set (k %)) xs)
        words (apply set/union sets)]
    (into {} (map-indexed (fn [idx v] [v idx]) words))))

(defn replace-w-idx [k dic]
  (fn [x]
    (let [tags (k x)
          k (keyword (str (name k) 1))]
      (assoc-in x [k] (set (map (fn [t] (get dic t 0)) tags))))))

(defn export-entry-stories [{:keys [current-state]}]
  (info "Export for TensorFlow: story predictions")
  (let [entries-map (:entries-map (gq/get-filtered current-state {:n n}))
        filtered (filtered-examples entries-map)
        tags-dict (dict :tags filtered)
        mentions-dict (dict :mentions filtered)
        tags-idxr (replace-w-idx :tags tags-dict)
        mentions-idxr (replace-w-idx :mentions mentions-dict)
        filtered (->> filtered
                      (map tags-idxr)
                      (map mentions-idxr))
        labeled (filter #(identity (:primary-story %)) filtered)
        unlabeled (mapv (example-fmt features)
                        (filter #(not (:primary-story %)) filtered))
        stories (-> (map :primary-story labeled)
                    (set)
                    (sort)
                    (vec))
        idx-m (into {} (map-indexed (fn [idx v] [v idx]) stories))
        w-story-idx (map (fn [x] (update x :primary-story #(get idx-m %))) labeled)
        examples (shuffle (map (example-fmt features-label) w-story-idx))
        geohashes-labeled (set (map second examples))
        geohashes-unlabeled (set (map second unlabeled))
        geohashes (set/union geohashes-labeled geohashes-unlabeled)
        _geo-idx-m (into {} (map-indexed (fn [idx v] [v idx]) geohashes))
        n (count examples)
        n-stories (count stories)
        [training-data test-data] (split-at (int (* n 0.7)) examples)]
    (info "encountered" n-stories "stories in" n "examples")
    (info "encountered" (count tags-dict) "tags")
    (info "encountered" (count mentions-dict) "mentions")
    (info (count geohashes-labeled)
          (count geohashes-unlabeled)
          (count geohashes)
          "geohashes labeled/unlabeled/total")
    (write-csv training-csv (into [(mapv pascal features-label)] training-data))
    (write-csv test-csv (into [(mapv pascal features-label)] test-data))
    (write-csv unlabeled-csv (into [(mapv pascal features)] unlabeled))
    (write-csv stories-csv (mapv (fn [x] [x]) stories))
    (write-csv geohashes-csv (mapv (fn [x] [x]) geohashes))
    stories))

(defn import-predictions [cmp-state]
  (try
    (when (fs/exists? predictions-csv)
      (with-open [reader (clojure.java.io/reader predictions-csv)]
        (let [stories (mapv #(Long/parseLong %) (s/split-lines (slurp stories-csv)))
              lines (line-seq reader)]
          (swap! cmp-state assoc-in [:story-predictions] {})
          (doseq [line lines]
            (try
              (let [[ts p-1 ranked] (s/split line #",")
                    ts (Long/parseLong ts)
                    p-1 (Float/parseFloat p-1)
                    ranked (edn/read-string ranked)
                    p {:ranked (mapv #(get stories %) ranked)
                       :p-1    p-1}]
                (when (> p-1 0.5)
                  (swap! cmp-state assoc-in [:story-predictions ts] p)))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info (count lines) "predictions parsed")
          (info (count (:story-predictions @cmp-state)) "predictions added"))))
    (catch Exception ex (error ex))))

(defn learn-stories [{:keys [cmp-state] :as msg-map}]
  (future
    (try
      (let [stories (export-entry-stories msg-map)
            estimator (str fu/app-path "/src/tensorflow/custom_estimator.py")
            classes-arg (str "--classes=" (count stories))]
        (info "running" estimator)
        (info (let-programs [python3 "/usr/local/bin/python3"]
                            (python3 estimator classes-arg "--train_steps=3000")))
        (import-predictions cmp-state))
      (catch Exception ex (error ex))))
  {})
