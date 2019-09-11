(ns meins.electron.renderer.ui.locations-map
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [cljs.nodejs :refer [process]]
            [cljs-bean.core :refer [bean ->clj ->js]]
            [mapbox-gl :refer [Map Popup]]
            ["react-day-picker" :default DayPicker]
            ["react-day-picker/DayPickerInput" :default DayPickerInput]
            ["moment" :as moment]
            [meins.electron.renderer.ui.entry.carousel :as carousel]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.graphql :as gql]
            [cljs.tools.reader.edn :as edn]
            [clojure.pprint :as pp]
            [matthiasn.systems-toolbox.component :as stc]))

(def day-picker (r/adapt-react-class DayPicker))
(def day-picker-input (r/adapt-react-class DayPickerInput))

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

(def buildings-cfg
  {:id           "3d-buildings"
   :source       "composite"
   :source-layer "building"
   :filter       ["==" "extrude" "true"]
   :type         "fill-extrusion"
   :minzoom      15
   :paint        {:fill-extrusion-color   "#aaa"
                  :fill-extrusion-height  ["interpolate" ["linear"] ["zoom"]
                                           15 0
                                           15.05 ["get" "height"]]
                  :fill-extrusion-base    ["interpolate" ["linear"] ["zoom"]
                                           15 0
                                           15.05 ["get" "min_height"]]
                  :fill-extrusion-opacity 0.6}})

(def styles
  {:street            "mapbox://styles/mapbox/streets-v11"
   :dark              "mapbox://styles/mapbox/dark-v10"
   :light             "mapbox://styles/mapbox/light-v10"
   :satellite         "mapbox://styles/mapbox/satellite-v9"
   :satellite-streets "mapbox://styles/mapbox/satellite-streets-v11"})

(defn add-layers [mb-map]
  (.addLayer mb-map (clj->js points-cfg))
  (.addLayer mb-map (clj->js buildings-cfg)))

(defn heatmap-did-mount [props]
  (fn []
    (let [{:keys [local]} props
          opts {:container "heatmap"
                :zoom      1
                :center    [10.1 53.56]
                :pitch     0
                :style     (:dark styles)}
          mb-map (Map. (clj->js opts))
          loaded (fn []
                   (.addSource mb-map "locations" (clj->js heatmap-data))
                   ;(.addLayer mb-map (clj->js heatmap-cfg) "waterway-label")
                   (add-layers mb-map))
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
                            (let [{:keys [local]} props]
                              [:div#heatmap {:style {:width            "100vw"
                                                     :height           "100vh"
                                                     :background-color "#333"}}]))}))

(defn query [local]
  (emit [:gql/query {:id       :locations-by-days
                     :q        (gql/gen-query [:locations_by_day
                                               {:from (:from @local)
                                                :to   (:to @local)}
                                               [:type
                                                [:geometry [:type
                                                            :coordinates]]
                                                [:properties [:activity
                                                              :data
                                                              :timestamp
                                                              :entry_type]]]])
                     :res-hash nil
                     :prio     15}]))

(defn locations-map []
  (let [backend-cfg (subscribe [:backend-cfg])
        gql-res (subscribe [:gql-res])
        local (r/atom {:gallery true
                       :from    (h/ymd (stc/now))
                       :to      (h/ymd (stc/now))})
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
        p1 #(let [mb-map (:mb-map @local)]
              (.flyTo mb-map (clj->js {:center [10.001872149129213
                                                53.561938271672375]
                                       :speed  0.8
                                       :pitch  45
                                       :zoom   16})))
        date-pick (fn [d]
                    (let [ymd (h/ymd (moment. d))]
                      (swap! local assoc :from ymd)
                      (swap! local assoc :to ymd)))]
    (fn []
      (query local)
      (let [mapbox-token (:mapbox-token @backend-cfg)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [:div.heatmap
            [:div.ctrl
             [day-picker-input {:style          {:padding-right 20}
                                :onDayChange    date-pick
                                :value          (:from @local)
                                :format         "yyyy-MM-dd"
                                :dayPickerProps {:showWeekNumbers true}}]
             [:select {:value     :dark
                       :style     {:padding-right 20}
                       :on-change (fn [ev]
                                    (let [tv (h/target-val ev)
                                          mb-map (:mb-map @local)]
                                      (info tv)
                                      (.setStyle mb-map tv)
                                      (add-layers mb-map)))}
              (for [[k style-url] styles]
                ^{:key k}
                [:option {:value style-url} k])]
             [:button {:on-click p1
                       :style    {:margin-left 20}}
              "p1"]
             [:button {:on-click get-bounds} "search"]]
            [heatmap-cls {:local local}]
            (when (:gallery @local)
              [:div.fixed-gallery
               [carousel/gallery @entries {} emit]])]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))
