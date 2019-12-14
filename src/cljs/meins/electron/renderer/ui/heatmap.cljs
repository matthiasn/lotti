(ns meins.electron.renderer.ui.heatmap
  (:require [cljs-bean.core :refer [->js]]
            [cljs.pprint :as pp]
            [cljs.tools.reader.edn :as edn]
            [mapbox-gl :refer [Map Popup]]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.carousel :as carousel]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(def heatmap-data
  {:type "geojson"
   :data (str h/export "entries.geojson")})

(def heatmap-cfg
  {:id     "locations-heat"
   :type   "heatmap"
   :source "locations"
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

(def points-cfg
  {:id     "points"
   :type   "circle"
   :source "locations"
   :paint  {:circle-radius 6
            :circle-color  ["match"
                            ["get" "activity"]
                            "on_foot" "green"
                            "walking" "darkgreen"
                            "running" "red"
                            "in_vehicle" "blue"
                            "on_bicycle" "orange"
                            "still" "#AAA"
                            "#888"]}})

(defn heatmap-did-mount [props]
  (fn []
    (let [{:keys [local]} props
          opts {:container "heatmap"
                :zoom      1
                :center    [10.1 53.56]
                :style     "mapbox://styles/mapbox/dark-v9"}
          mb-map (Map. (clj->js opts))
          loaded (fn []
                   (.addSource mb-map "locations" (clj->js heatmap-data))
                   ;(.addLayer mb-map (clj->js heatmap-cfg) "waterway-label")
                   (.addLayer mb-map (clj->js points-cfg)))
          hide-gallery #(swap! local assoc-in [:gallery] false)
          popup (Popup. (->js {:closeButton  false
                               :closeOnClick false}))
          mouse-leave (fn []
                        (let [canvas (.getCanvas mb-map)]
                          (.remove popup)
                          (aset canvas "style" "cursor" "")))
          mouse-enter (fn [e]
                        (let [canvas (.getCanvas mb-map)
                              feature (aget e "features" 0)
                              coords (aget feature "geometry" "coordinates")
                              data (edn/read-string (aget feature "properties" "data"))
                              html (str "<pre><code>" (with-out-str (pp/pprint data)) "</code></pre>")]
                          (aset canvas "style" "cursor" "pointer")
                          (js/console.info data)
                          (-> popup
                              (.setLngLat coords)
                              (.setHTML html)
                              (.addTo mb-map))))]
      (swap! local assoc-in [:mb-map] mb-map)
      (aset js/window "heatmap" mb-map)
      (.on mb-map "load" loaded)
      (.on mb-map "zoomstart" hide-gallery)
      (.on mb-map "mouseenter" "points" mouse-enter)
      (.on mb-map "mouseleave" "points" mouse-leave))))

(defn heatmap-cls [props]
  (r/create-class
    {:component-did-mount (heatmap-did-mount props)
     :reagent-render      (fn [props]
                            (let [{:keys []} props]
                              [:div#heatmap {:style {:width            "100vw"
                                                     :height           "100vh"
                                                     :background-color "#333"}}]))}))

(defn heatmap []
  (let [backend-cfg (subscribe [:backend-cfg])
        gql-res (subscribe [:gql-res])
        local (r/atom {:gallery true})
        toggle-photos #(swap! local update-in [:gallery] not)
        get-bounds #(let [mb-map (:mb-map @local)
                          bounds (.getBounds mb-map)
                          zoom (.getZoom mb-map)
                          ne (.-_ne bounds)
                          sw (.-_sw bounds)
                          center (.getCenter mb-map)
                          q (gql/gen-query
                              [:photos_by_location {:ne_lat (.-lat ne)
                                                    :ne_lon (.-lng ne)
                                                    :sw_lat (.-lat sw)
                                                    :sw_lon (.-lng sw)}
                               [:timestamp :img_file :latitude :longitude
                                :md :starred :stars :text]])]
                      (info "heatmap gql" q zoom center)
                      (emit [:gql/query {:q        q
                                         :res-hash nil
                                         :id       :heatmap}]))
        entries (reaction (->> @gql-res
                               :heatmap
                               :data
                               :photos_by_location
                               (filter :img_file)))
        p0 #(let [mb-map (:mb-map @local)]
              (.flyTo mb-map (clj->js {:center [10.001872149129213
                                                53.561938271672375]
                                       :zoom   1})))
        p1 #(let [mb-map (:mb-map @local)]
              (.flyTo mb-map (clj->js {:center [10.001872149129213
                                                53.561938271672375]
                                       :speed  0.6
                                       :zoom   10})))
        p2 #(let [mb-map (:mb-map @local)]
              (.flyTo mb-map (clj->js {:center [17.113231048664147
                                                48.14863673388942]
                                       :speed  0.8
                                       :zoom   13.815236381703615})))
        p3 #(let [mb-map (:mb-map @local)]
              (.flyTo mb-map (clj->js {:center [96.17530739999074
                                                16.802089304852103]
                                       :zoom   12.743812567839447})))]
    (fn []
      (let [mapbox-token (:mapbox-token @backend-cfg)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [:div.heatmap
            [:div.ctrl
             [:button {:on-click p0} "p0"]
             [:button {:on-click p1} "p1"]
             [:button {:on-click p2} "p2"]
             [:button {:on-click p3} "p3"]
             [:button {:on-click get-bounds} "search"]
             [:button {:on-click toggle-photos}
              (str (if (:gallery @local) "hide " "show ")
                   (count @entries)
                   " photos")]]
            [heatmap-cls {:local local}]
            (when (:gallery @local)
              [:div.fixed-gallery
               [carousel/gallery @entries {}]])]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))
