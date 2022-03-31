(ns meins.electron.renderer.ui.leaflet
  (:require [leaflet]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as rc]
            [taoensso.timbre :refer [info]]))

(defn leaflet-did-mount
  "Function using the did-mount lifecycle method. Uses :id from props map to
   determine id to render into, and then sets the view to latitude and
   longitude, also from the props map."
  [props]
  (fn []
    (let [{:keys [lat lon zoom ts bounds]} props
          zoom (or zoom 13)
          iww-host (.-iwwHOST js/window)
          map-cfg (clj->js {:scrollWheelZoom false})
          map (.setView (.map leaflet (:id props) map-cfg) #js [lat lon] zoom)
          tiles-url (str "http://" iww-host "/tiles/{z}/{x}/{y}.png")]
      (.addTo (.tileLayer leaflet tiles-url (clj->js {:maxZoom 18})) map)
      (when-not bounds
        (.addTo (.marker leaflet #js [lat lon]) map))
      (.on map "zoomend" #(emit [:entry/update-local
                                 {:map-zoom  (aget % "target" "_zoom")
                                  :timestamp ts}]))
      (when bounds
        (-> (leaflet/rectangle (clj->js bounds)
                               (clj->js {:color  "blue"
                                         :weight 2}))
            (.addTo map))
        (.fitBounds map (leaflet/latLngBounds (clj->js bounds)))))))

(defn leaflet-component
  "Creates a leaflet map reagent class. The reagent-render function only creates
   a div with the id from the props map. The component-did-mount then fills the
   map div with life, with the latitude and longitude from props.
   TODO: disable zoom, other options for map; change map when data changes"
  [props]
  (set! (.-imagePath js/L.Icon.Default) "../resources/public/images/")
  (rc/create-class
    {:component-did-mount (leaflet-did-mount props)
     :reagent-render      (fn [props] [:div.leaflet {:id (:id props)}])}))

(defn leaflet-map
  "Helper for showing map when exists and desired."
  [entry show? local-cfg]
  (let [{:keys [latitude longitude timestamp map-zoom]} entry]
    (when (and show? latitude)
      ^{:key (str latitude longitude)}
      [leaflet-component {:id   (str "map" timestamp (:query-id local-cfg))
                          :lat  latitude
                          :lon  longitude
                          :zoom map-zoom
                          :ts   timestamp}])))
