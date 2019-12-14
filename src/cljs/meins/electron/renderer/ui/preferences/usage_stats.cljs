(ns meins.electron.renderer.ui.preferences.usage-stats
  (:require ["ngeohash" :as geohash]
            [clojure.pprint :as pp]
            [meins.electron.renderer.ui.leaflet :as l]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as rc]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn gh-2-bounds [geohash]
  (let [bounding-box (js->clj (geohash/decode_bbox geohash))
        [minlat minlon maxlat maxlon] bounding-box]
    [[minlat minlon] [maxlat maxlon]]))

(defn gh-map [geohash]
  (when geohash
    (let [bounds (gh-2-bounds geohash)]
      [:div
       [l/leaflet-component
        {:id     (str "gh-" geohash)
         :lat    0
         :lon    0
         :bounds bounds
         :put-fn emit}]])))


(defn usage []
  (let [gql-res (subscribe [:gql-res])
        usage-by-day (reaction (-> @gql-res :usage-by-day :data :usage_by_day))]
    (fn usage-render []
      (let [usage @usage-by-day]
        [:div.usage
         [:div.view
          [:h2 "Usage Stats"]
          [:table
           [:tdata
            [:tr
             [:td "ID Hash:"]
             [:td (:id_hash usage)]]
            [:tr
             [:td "Entries:"]
             [:td (:entries usage)]]
            [:tr
             [:td "Words:"]
             [:td (:words usage)]]
            [:tr
             [:td "Sagas:"]
             [:td (:sagas usage)]]
            [:tr
             [:td "Stories:"]
             [:td (:stories usage)]]
            [:tr
             [:td "Habits:"]
             [:td (:habits usage)]]
            [:tr
             [:td "Hashtags:"]
             [:td (:hashtags usage)]]
            [:tr
             [:td "Hours logged:"]
             [:td (:hours_logged usage)]]
            [:tr
             [:td "Operating System:"]
             [:td (:os usage)]]
            [:tr
             [:td "Query duration (ms):"]
             [:td (:dur usage)]]]]
          (for [gh (:geohashes usage)]
            [gh-map gh])]]))))
