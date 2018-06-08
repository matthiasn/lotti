(ns meo.jvm.utils.images
  "Utils for image conversion and manipulation."
  (:require [image-resizer.format :refer :all]
            [image-resizer.resize :refer :all]
            [image-resizer.scale-methods :refer :all]
            [image-resizer.rotate :refer :all]
            [image-resizer.util :refer :all]
            [clojure.string :as s]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.file-utils :as fu])
  (:import (com.drew.imaging ImageMetadataReader)))

(defn extract-from-tag
  "Creates map for a single Exif directory.
  Borrowed from: https://github.com/joshuamiller/exif-processor"
  [tag]
  (into {} (map #(hash-map (.getTagName %) (.getDescription %)) tag)))

(defn extract-exif [file]
  (let [metadata (ImageMetadataReader/readMetadata file)
        exif-directories (.getDirectories metadata)
        tags (map #(.getTags %) exif-directories)
        exif (into {} (map extract-from-tag tags))]
    exif))

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
  (let [resize (resize-fn max-w-h max-w-h quality)
        new-filename (str fu/thumbs-path max-w-h "/" filename)]
    (as-file (resize img) new-filename :verbatim)))

(defn gen-thumbs [file filename]
  (let [rotated (rotate file)]
    (info "generating thumbs for" filename)
    (resize-save filename rotated 256)
    (resize-save filename rotated 512)
    (resize-save filename rotated 2048)))
