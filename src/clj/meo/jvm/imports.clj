(ns meo.jvm.imports
  (:require [meo.jvm.imports.screenshot :as is]
            [meo.jvm.imports.spotify :as iss]
            [meo.jvm.imports.entries :as ie]
            [meo.jvm.imports.flight :as fl]
            [meo.jvm.imports.media :as im]))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/photos     im/import-media
                 :import/screenshot is/import-screenshot
                 :import/movie      im/import-movie
                 :import/spotify    iss/import-spotify
                 :import/flight     fl/import-flight}})
