(ns meo.jvm.routes.map-tile
  "Route for serving map tile images. These images are cached locally so they
   are only retrieved once and stay available offline."
  (:require [compojure.core :refer [GET]]
            [meo.jvm.files :as f]
            [clojure.java.io :as io]
            [clj-http.client :as client]
            [clojure.tools.logging :as log]
            [me.raynes.fs :as fs]
            [meo.jvm.file-utils :as fu]))

(def map-tile-route
  (GET "/tiles/:z/:x/:y" [z x y :as r]
    (let [file-path (str z "/" x "/" y)
          filename (str fu/data-path "/tiles/" file-path)
          file (java.io.File. filename)]
      (io/make-parents file)
      (when-not (fs/exists? filename)
        (let [tile-url (str "http://a.tile.osm.org/" file-path)
              res (client/get tile-url {:as :byte-array
                                        :headers {"user-agent" "meo"}})
              body (:body res)]
          (log/info "Retrieved map tile" tile-url)
          (io/copy body file)))
      (log/info "Serving map tile" file-path)
      {:body file})))
