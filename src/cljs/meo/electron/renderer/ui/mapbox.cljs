(ns meo.electron.renderer.ui.mapbox
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [cljs.nodejs :refer [process]]
            [mapbox-gl]))

(def heatmap-data
  {:type "geojson"
   :data "/tmp/entries.geojson"})

(def heatmap-cfg
  {:id      "earthquakes-heat"
   :type    "heatmap"
   :source  "earthquakes"
   :paint   {:heatmap-weight    ["interpolate"
                                 ["linear"]
                                 ["get" "mag"]
                                 0 0
                                 6 1]
             :heatmap-intensity ["interpolate"
                                 ["linear"]
                                 ["zoom"]
                                 0 1
                                 9 3]
             :heatmap-color     ["interpolate"
                                 ["linear"]
                                 ["heatmap-density"]
                                 0 "rgba(33,102,172,0)"
                                 0.2 "rgb(103,169,207)"
                                 0.4 "rgb(209,229,240)"
                                 0.6 "rgb(253,219,199)"
                                 0.8 "rgb(239,138,98)"
                                 1 "rgb(178,24,43)"]
             :heatmap-radius    ["interpolate"
                                 ["linear"]
                                 ["zoom"]
                                 0 2
                                 13 20]
             :heatmap-opacity   ["interpolate"
                                 ["linear"]
                                 ["zoom"]
                                 10 1
                                 25 0]}})

(defn mapbox-did-mount [props]
  (fn []
    (let [{:keys [put-fn local]} props
          opts {:container "heatmap"
                :zoom      3
                :center    [9 55]
                :style     "mapbox://styles/mapbox/dark-v9"}
          mb-map (mapbox-gl/Map. (clj->js opts))
          loaded (fn []
                   (.addSource mb-map "earthquakes"
                               (clj->js heatmap-data))
                   (.addLayer mb-map (clj->js heatmap-cfg) "waterway-label"))]
      (.on mb-map "load" loaded))))

(defn mapbox-cls [props]
  (r/create-class
    {:component-did-mount (mapbox-did-mount props)
     :reagent-render      (fn [props]
                            (let [{:keys [local]} props]
                              [:div#heatmap {:style {:width            "100vw"
                                                     :height           "100vh"
                                                     :background-color :white}}]))}))

(defn mapbox-map [put-fn]
  (let [backend-cfg (subscribe [:backend-cfg])
        local (r/atom {:zoom 1})]
    (fn [put-fn]
      (let [mapbox-token (:mapbox-token @backend-cfg)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [mapbox-cls {:local  local
                        :put-fn put-fn}]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))
