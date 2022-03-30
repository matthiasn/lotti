(ns meins.jvm.utils.images
  "Utils for image conversion and manipulation."
  (:require [clojure.string :as s]
            [image-resizer.format :refer [as-file]]
            [image-resizer.resize :refer [resize-fn]]
            [image-resizer.rotate :refer [rotate-180-counter-clockwise-fn
                                          rotate-270-counter-clockwise-fn
                                          rotate-90-counter-clockwise-fn]]
            [image-resizer.scale-methods :refer [quality]]
            [image-resizer.util :refer [buffered-image]]
            [me.raynes.fs :as fs]
            [meins.jvm.file-utils :as fu]
            [taoensso.timbre :refer [debug error info warn]])
  (:import (com.drew.imaging ImageMetadataReader)))

(defn extract-from-tag
  "Creates map for a single Exif directory.
  Borrowed from: https://github.com/joshuamiller/exif-processor"
  [tag]
  (into {} (map #(hash-map (.getTagName %) (.getDescription %)) tag)))

(defn extract-exif [file]
  (try
    (let [metadata (ImageMetadataReader/readMetadata file)
          exif-directories (.getDirectories metadata)
          tags (map #(.getTags %) exif-directories)
          exif (into {} (map extract-from-tag tags))]
      exif)
    (catch Exception ex (warn "could not parse EXIF in" file ex) {})))

(defn rotate [file]
  (let [exif (extract-exif file)
        orientation (get exif "Orientation" "")
        rotate (cond (s/includes? orientation "(Rotate 90 CW)")
                     (rotate-270-counter-clockwise-fn)
                     (s/includes? orientation "(Rotate 180)")
                     (rotate-180-counter-clockwise-fn)
                     (s/includes? orientation "(Rotate 270 CW)")
                     (rotate-90-counter-clockwise-fn)
                     :else buffered-image)]
    (rotate (buffered-image file))))

(defn rotate-resize [file max-w-h]
  (let [resize (resize-fn max-w-h max-w-h quality)]
    (resize (rotate file))))

(defn resize-save [filename img max-w-h]
  (let [new-filename (str fu/thumbs-path max-w-h "/" filename)]
    (if (fs/exists? new-filename)
      (warn "File exists:" new-filename)
      (let [resize (resize-fn max-w-h (* max-w-h 4) quality)]
        (as-file (resize img) new-filename :verbatim)))))

(defn gen-thumbs [file filename]
  (let [rotated (rotate file)]
    (info "generating thumbs for" filename)
    (resize-save filename rotated 256)
    (resize-save filename rotated 512)
    (resize-save filename rotated 2048)))
