(ns meo.jvm.graph.geo
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [geo [geohash :as geohash]
             [jts :as jts] [spatial :as sp] [io :as gio]]
            ))

(defn photos-within-bounds [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [ne sw center]} msg-payload
        n Integer/MAX_VALUE
        res (gq/get-filtered current-state {:tags #{"#photo"} :n n})
        entries (vals (:entries-map res))
        center (sp/spatial4j-point (:lat center) (:lon center))
        ne (sp/spatial4j-point (:lat ne) (:lon ne))
        sw (sp/spatial4j-point (:lat sw) (:lon sw))
        diagonal (sp/distance ne sw)
        r (/ diagonal 2)
        circle (sp/circle center r)
        nearby (fn [entry]
                 (let [{:keys [latitude longitude]} entry]
                   (when (and latitude longitude)
                     (let [point (sp/spatial4j-point latitude longitude)]
                       (sp/intersects? point circle)))))
        entries (filter nearby entries)
        timestamps (map :timestamp entries)]
    (info "photos-within-bounds" (count entries) msg-payload)
    {:emit-msg [:search/res {:type :geo-photos
                             :data timestamps}]}))
