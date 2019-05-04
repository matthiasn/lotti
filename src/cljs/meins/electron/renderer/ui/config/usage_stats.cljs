(ns meins.electron.renderer.ui.config.usage-stats
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as rc]
            ["ngeohash" :as geohash]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error]]
            [clojure.pprint :as pp]
            [meins.electron.renderer.ui.leaflet :as l]
            [meins.electron.renderer.graphql :as gql]
            [venia.core :as v]))

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

(defn usage-query []
  (let [q {:query/data [:usage_by_day
                        [:id_hash
                         :entries
                         :hours_logged
                         :tasks
                         :tasks_done
                         :habits
                         :hashtags
                         :words
                         :stories
                         :sagas
                         :dur
                         :geohashes]]}]
    (v/graphql-query {:venia/queries [q]})))

(defn usage []
  (let [local (rc/atom {})
        gql-res (subscribe [:gql-res])
        usage-by-day (reaction (-> @gql-res :usage-by-day :data :usage_by_day))
        q (usage-query)]
    (emit [:gql/query {:q        q
                       :res-hash nil
                       :id       :usage-by-day
                       :prio     15}])
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
             [:td "Time to create usage report:"]
             [:td (:dur usage)]]]]
          (for [gh (:geohashes usage)]
            [gh-map gh])]]))))
