(ns meins.electron.renderer.ui.config.usage-stats
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as rc]
            ["ngeohash" :as geohash]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error]]
            [clojure.pprint :as pp]
            [meins.electron.renderer.ui.leaflet :as l]))

(defn gh-2-bounds [geohash precision]
  (let [shortened (subs geohash 0 precision)
        bounding-box (js->clj (geohash/decode_bbox shortened))
        [minlat minlon maxlat maxlon] bounding-box]
    [[minlat minlon] [maxlat maxlon]]))


(defn gh-map [geohash]
  (when geohash
    (let [bounds (gh-2-bounds geohash 3)]
      [:div
       [l/leaflet-component
        {:id     (str "gh-" geohash)
         :lat    0
         :lon    0
         :bounds bounds
         :put-fn emit}]])))

(defn usage []
  (let [local (rc/atom {})
        geohashes ["u0yh" "u1x0"]]
    (fn usage-render []
      (let []
        [:div.usage
         [:div.settings
          [:h2 "Usage Stats"]
          (for [gh geohashes]
            [gh-map gh])]]))))
