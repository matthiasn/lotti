(ns meins.jvm.imports.media
  "This namespace does imports, for example of photos."
  (:require [cheshire.core :as cc]
            [clj-http.client :as hc]
            [clj-time.coerce :as c]
            [clj-time.core :as t]
            [clj-time.format :as tf]
            [clojure.java.io :as io]
            [clojure.string :as s]
            [me.raynes.fs :as fs]
            [meins.common.specs]
            [meins.common.utils.misc :as m]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.utils.images :as img]
            [taoensso.timbre :refer [error info warn]]))

(defn dms-to-dd
  "Converts DMS (degree, minute, second) to DD (decimal degree) format. Returns
   nil when not all 3 groups dm, m, and s are contained in coord string. Result
   negative when coord in Western or Southern Hemisphere according to ref
   argument."
  [exif coord-key ref-key]
  (let [coord (get exif coord-key)
        ref (get exif ref-key)]
    (when coord
      (let [matcher (re-matcher #"(\d{1,3})° (\d{1,2})' (\d{1,2}\.?\d+?)" coord)
            [_dms d m s] (re-find matcher)]
        (when (and d m s)
          (let [d (read-string d)
                m (read-string m)
                s (read-string s)
                dd (float (+ d (/ m 60) (/ s 3600)))]
            (if (contains? #{"W" "S"} ref)
              (- dd)
              dd)))))))

(defn add-filename-offset
  "Add the last three digits of the filename to the timestamp in order to avoid
   collisions when photos were taken in burst mode on the iPhone, as
   unfortunately the photo timestamp is only precise to the second and the
   capture rate for iPhone 6s is 10fps."
  [millis filename]
  (let [filename-number (re-find #"\d{3}(?=\.)" filename)
        offset (if filename-number (Integer. filename-number) 0)]
    (+ millis offset)))

(defn extract-gps-ts
  "Converts concatenated GPS timestamp strings into milliseconds since epoch.
  Example from iPhone 6s camera app:
    'GPS Date Stamp' '2016:03:30'
    'GPS Time-Stamp' '20:07:57.00 UTC'"
  [ts filename]
  (let [f (tf/formatter "yyyy:MM:dd HH:mm:ss.SS z")]
    (when (and (seq ts)
               (re-matches
                 #"\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}\.\d{2} [A-Z]{1,5}" ts))
      (add-filename-offset (c/to-long (tf/parse f ts)) filename))))

(defn extract-ts
  "Converts 'Date/Time' exif tag into milliseconds since epoch. Assumes local
   timezone at the time of importing a photo, which may or may not be accurate.
   In case of iPhone, this is only relevant for screenshots, media saved to
   local camera roll or when no GPS available, such as in the case of being in
   an aircraft (airplane mode). This is unfortunate, why would they not just use
   UTC all the time?"
  [ts filename]
  (let [dtz (t/default-time-zone)
        f (tf/formatter "yyyy:MM:dd HH:mm:ss" dtz)]
    (when (and (seq ts)
               (re-matches #"\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}" ts))
      (add-filename-offset (c/to-long (tf/parse f ts)) filename))))

(defn import-image
  "Takes an image file (as a java.io.InputStream or java.io.File) and extracts
   exif information into a map.
   Borrowed and modified from: https://github.com/joshuamiller/exif-processor"
  [file]
  (let [filename (.getName file)
        rel-path (.getPath file)
        exif (img/extract-exif file)
        orientation (get exif "Orientation" "")
        orientation (cond (s/includes? orientation "(Rotate 90 CW)")
                          :rotate-90-cw
                          (s/includes? orientation "(Rotate 180)")
                          :rotate-180
                          (s/includes? orientation "(Rotate 270 CW)")
                          :rotate-270-cw
                          :else :none)
        timestamp (or
                    (extract-gps-ts (str (get exif "GPS Date Stamp") " "
                                         (get exif "GPS Time-Stamp")) filename)
                    (extract-ts (str (get exif "Date/Time Digitized")) filename)
                    (extract-ts (str (get exif "Date/Time")) filename)
                    (extract-ts (str (get exif "Date/Time Original")) filename)
                    (.lastModified file))
        target-filename (str timestamp "-" filename)]
    (fs/copy rel-path (str fu/img-path target-filename))
    (img/gen-thumbs file target-filename)
    {:timestamp    timestamp
     :latitude     (dms-to-dd exif "GPS Latitude" "GPS Latitude Ref")
     :longitude    (dms-to-dd exif "GPS Longitude" "GPS Longitude Ref")
     :img_file     target-filename
     :img_rel_path rel-path
     :img          {:orientation orientation}
     :md           ""
     :tags         #{"#import"}
     :perm_tags    #{"#photo"}}))

(defn gen-thumbs [{:keys [msg-payload]}]
  (let [{:keys [filename full-path]} msg-payload]
    (img/gen-thumbs (io/file full-path) filename))
  {})

(defn import-video
  "Takes a video file (as a java.io.InputStream or java.io.File) and creates
   entry from it."
  [file]
  (let [filename (.getName file)
        rel-path (.getPath file)
        timestamp (.lastModified file)
        target-filename (str timestamp "-" filename)]
    (fs/rename rel-path (str fu/data-path "/videos/" target-filename))
    {:timestamp  timestamp
     :video-file target-filename
     :md         "some #video"
     :tags       #{"#video" "#import"}}))

(defn import-audio
  "Takes an audio file (as a java.io.InputStream or java.io.File) creates entry
   from it."
  [audio-file]
  (let [filename (.getName audio-file)
        ts-str (subs filename 0 15)
        f (tf/formatter "yyyyMMdd HHmmss")
        timestamp (.lastModified audio-file)
        rel-path (.getPath audio-file)
        target-filename (s/replace (str timestamp "-" filename) " " "_")]
    (fs/rename rel-path (str fu/data-path "/audio/" target-filename))
    {:timestamp  (c/to-long (tf/parse f ts-str))
     :audio-file target-filename
     :md         "some #audio"
     :tags       #{"#audio" "#import"}}))

(defn import-photos
  "Imports photos selected in UI. Expects message payload to be a vector with
   full file paths."
  [{:keys [put-fn msg-payload msg-meta]}]
  (doseq [filepath msg-payload]
    (let [file (io/file filepath)
          filename (.getName file)]
      (info "Importing " filename)
      (try (let [file-info (import-image file)]
             (when file-info
               (put-fn (with-meta [:entry/update file-info] msg-meta))))
           (catch Exception ex (error (str "Error while importing "
                                           filename) ex)))))
  {})

(defn gen-cache
  [{:keys []}]
  (let [files (file-seq (io/file fu/img-path))
        done (atom 0)
        n (count files)]
    (info "generating thumbnails for" n "images")
    (future
      (doseq [file files]
        (let [filename (.getName file)]
          (try
            (img/gen-thumbs file filename)
            (swap! done inc)
            (info "generated thumbnails" @done "of" n "-" filename)
            ;(put-fn [:photos/gen-cache-progress {:n n :done @done}])
            (catch Exception ex (warn "Creating thumbnails" filename ex)))))))
  {})

(defn update-audio-tag
  [entry]
  (if (:audio-file entry)
    (-> entry
        (update-in [:tags] conj "#audio")
        (update-in [:md] str " #audio"))
    entry))

(defn import-movie
  "Imports movie metadata from IMDb."
  [{:keys [msg-payload]}]
  (info "importing movie" msg-payload)
  (let [imdb-id (:imdb-id msg-payload)
        parser (fn [res] (cc/parse-string (:body res) #(keyword (m/lower-case %))))
        res (hc/get (str "http://www.omdbapi.com/?i=" imdb-id))
        imdb (parser res)
        series (when-let [sid (:seriesid imdb)]
                 {:series (parser
                            (hc/get (str "http://www.omdbapi.com/?i=" sid)))})]
    (if (:error imdb)
      (error "could not find on omdbapi.com:" imdb-id)
      {:emit-msg [:entry/update (merge (:entry msg-payload)
                                       {:imdb (merge imdb series)})]})))
