(ns meo.jvm.graph.geo
  (:require [meo.jvm.graph.query :as gq]
            [taoensso.timbre :refer [info error warn debug]]
            [geo [spatial :as sp]])
  (:import [org.locationtech.spatial4j.shape.impl RectangleImpl]))

(defn photos-within-bounds [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [ne sw center]} msg-payload
        n Integer/MAX_VALUE
        res (gq/get-filtered current-state {:tags #{"#photo"} :n n})
        entries (vals (:entries-map res))
        center (sp/point (:lat center) (:lon center))
        ne (sp/point (:lat ne) (:lon ne))
        sw (sp/point (:lat sw) (:lon sw))
        rect (RectangleImpl. sw ne sp/earth)
        nearby (fn [entry]
                 (let [{:keys [latitude longitude img-file]} entry]
                   (when (and latitude longitude img-file)
                     (let [point (sp/point latitude longitude)]
                       (sp/intersects? rect point)))))
        entries (filter nearby entries)
        timestamps (map :timestamp entries)]
    (info "photos-within-bounds" (count entries) msg-payload (sp/area rect))
    {:emit-msg [:search/res {:type :geo-photos
                             :data timestamps}]}))
