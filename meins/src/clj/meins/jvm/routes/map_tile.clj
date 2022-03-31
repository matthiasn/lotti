(ns meins.jvm.routes.map-tile
  "Route for serving map tile images. These images are cached locally so they
   are only retrieved once and stay available offline."
  (:require [clj-http.client :as client]
            [clojure.java.io :as io]
            [compojure.core :refer [GET]]
            [me.raynes.fs :as fs]
            [meins.jvm.file-utils :as fu]
            [taoensso.timbre :refer [debug]]))

(def map-tile-route
  (GET "/tiles/:z/:x/:y" [z x y]
    (let [file-path (str z "/" x "/" y)
          filename (str fu/data-path "/tiles/" file-path)
          file (java.io.File. filename)]
      (io/make-parents file)
      (when-not (fs/exists? filename)
        (let [tile-url (str "http://a.tile.osm.org/" file-path)
              res (client/get tile-url {:as :byte-array
                                        :headers {"user-agent" "meins"}})
              body (:body res)]
          (debug "Retrieved map tile" tile-url)
          (io/copy body file)))
      (debug "Serving map tile" file-path)
      {:body file})))
