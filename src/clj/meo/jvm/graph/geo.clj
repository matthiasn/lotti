(ns meo.jvm.graph.geo
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [camel-snake-kebab.core :refer [->snake_case]]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [geo [spatial :as sp]]
            [meo.jvm.store :as st])
  (:import [org.locationtech.spatial4j.shape.impl RectangleImpl]))

(defn snake-xf [xs] (transform-keys ->snake_case xs))

(defn photos-within-bounds [context args value]
  (let [{:keys [ne_lat ne_lon sw_lat sw_lon]} args
        n Integer/MAX_VALUE
        res (gq/get-filtered @st/state {:tags #{"#photo"} :n n})
        entries (vals (:entries-map res))
        ne (sp/point ne_lat ne_lon)
        sw (sp/point sw_lat sw_lon)
        rect (RectangleImpl. sw ne sp/earth)
        nearby (fn [entry]
                 (let [{:keys [latitude longitude img-file]} entry]
                   (when (and latitude longitude img-file)
                     (let [point (sp/point latitude longitude)]
                       (sp/intersects? rect point)))))]
    (snake-xf (filter nearby entries))))
