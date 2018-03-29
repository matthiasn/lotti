(ns meo.jvm.routes.images
  "Functions for serving images."
  (:require [compojure.core :refer [GET]]
            [meo.jvm.files :as f]
            [clojure.java.io :as io]
            [meo.jvm.utils.images :as im]
            [image-resizer.format :refer :all]
            [image-resizer.resize :refer :all]
            [image-resizer.scale-methods :refer :all]
            [image-resizer.rotate :refer :all]
            [image-resizer.util :refer :all]
            [ring.middleware.params :as params]
            [clojure.string :as s]
            [taoensso.timbre :refer [info error warn debug]]
            [meo.jvm.file-utils :as fu]))

(def img-resized-route
  (params/wrap-params
    (GET "/photos2/:filename" [filename :as r]
      (let [filename (str fu/img-path filename)
            file (io/file filename)
            params (:params r)
            width (Integer/parseInt (or (get params "width") "1024"))
            rotated-resized (im/rotate-resize file width)]
        (debug "request" r "width" width)
        (as-stream-by-mime-type rotated-resized "image/jpeg")))))
