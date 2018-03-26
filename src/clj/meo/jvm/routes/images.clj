(ns meo.jvm.routes.images
  "Functions for serving images."
  (:require [compojure.core :refer [GET]]
            [meo.jvm.files :as f]
            [clojure.java.io :as io]
            [image-resizer.format :refer :all]
            [image-resizer.resize :refer :all]
            [image-resizer.scale-methods :refer :all]
            [image-resizer.rotate :refer :all]
            [image-resizer.util :refer :all]
            [meo.jvm.imports.media :as im]
            [clojure.string :as s]
            [meo.jvm.file-utils :as fu]))

(def img-resized-route
  (GET "/photos2/:filename" [filename :as r]
    (let [filename (str fu/img-path filename)
          file (io/file filename)
          exif (im/extract-exif file)
          orientation (get exif "Orientation" "")
          rotate-fn (cond (s/includes? orientation "(Rotate 90 CW)")
                          (rotate-270-counter-clockwise-fn)
                          (s/includes? orientation "(Rotate 180)")
                          (rotate-180-counter-clockwise-fn)
                          (s/includes? orientation "(Rotate 270 CW)")
                          (rotate-90-counter-clockwise-fn)
                          :else buffered-image)]
      (-> (buffered-image file)
          (rotate-fn)
          (as-stream-by-mime-type "image/jpeg")))))
