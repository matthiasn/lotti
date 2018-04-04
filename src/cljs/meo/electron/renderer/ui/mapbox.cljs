(ns meo.electron.renderer.ui.mapbox
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [cljs.nodejs :refer [process]]
            [mapbox-gl]
            [meo.electron.renderer.ui.entry.carousel :as carousel]))

(def heatmap-data
  {:type "geojson"
   :data "/tmp/entries.geojson"})

(def heatmap-cfg
  {:id     "earthquakes-heat"
   :type   "heatmap"
   :source "earthquakes"
   :paint  {:heatmap-weight    ["interpolate"
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
                :zoom      10
                :center    [10.1 53.56]
                :style     "mapbox://styles/mapbox/dark-v9"}
          mb-map (mapbox-gl/Map. (clj->js opts))
          loaded (fn []
                   (.addSource mb-map "earthquakes"
                               (clj->js heatmap-data))
                   (.addLayer mb-map (clj->js heatmap-cfg) "waterway-label"))]
      (swap! local assoc-in [:mb-map] mb-map)
      (aset js/window "heatmap" mb-map)
      (.on mb-map "load" loaded))))

(defn mapbox-cls [props]
  (r/create-class
    {:component-did-mount (mapbox-did-mount props)
     :reagent-render      (fn [props]
                            (let [{:keys [local]} props]
                              [:div#heatmap {:style {:width            "100vw"
                                                     :height           "100vh"
                                                     :background-color "#333"}}]))}))

(defn mapbox-map [put-fn]
  (let [backend-cfg (subscribe [:backend-cfg])
        geo-photos (subscribe [:geo-photos])
        fake-entry (reaction {:comments @geo-photos})
        local (r/atom {:zoom 1})
        get-bounds #(let [bounds (.getBounds (:mb-map @local))
                          ne (.-_ne bounds)
                          sw (.-_sw bounds)
                          center (.getCenter (:mb-map @local))
                          coord {:center {:lat (.-lat center)
                                          :lon (.-lng center)}
                                 :ne     {:lat (.-lat ne)
                                          :lon (.-lng ne)}
                                 :sw     {:lat (.-lat sw)
                                          :lon (.-lng sw)}}]
                      (put-fn [:search/geo-photo coord])
                      (info coord))]
    (fn [put-fn]
      (let [mapbox-token (:mapbox-token @backend-cfg)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [:div.heatmap
            [:div.ctrl
             [:button {:on-click get-bounds}
              "find photos"]]
            [mapbox-cls {:local  local
                         :put-fn put-fn}]
            (when @geo-photos
              [:div.fixed-gallery
               [carousel/gallery fake-entry {} put-fn]])]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))
