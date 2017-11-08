(ns meo.electron.renderer.ui.leaflet
  (:require [reagent.core :as rc]
            [leaflet]))

(defn leaflet-did-mount
  "Function using the did-mount lifecycle method. Uses :id from props map to
   determine id to render into, and then sets the view to latitude and
   longitude, also from the props map."
  [props]
  (fn []
    (let [{:keys [lat lon zoom put-fn ts]} props
          zoom (or zoom 13)
          iww-host (.-iwwHOST js/window)
          map-cfg (clj->js {:scrollWheelZoom false})
          map (.setView (.map leaflet (:id props) map-cfg) #js [lat lon] zoom)
          tiles-url (str "http://" iww-host "/tiles/{z}/{x}/{y}.png")]
      (.addTo (.tileLayer leaflet tiles-url (clj->js {:maxZoom 18})) map)
      (.addTo (.marker leaflet #js [lat lon]) map)
      (.on map "zoomend" #(put-fn [:entry/update-local
                                   {:map-zoom  (aget % "target" "_zoom")
                                    :timestamp ts}])))))

(defn leaflet-component
  "Creates a leaflet map reagent class. The reagent-render function only creates
   a div with the id from the props map. The component-did-mount then fills the
   map div with life, with the latitude and longitude from props.
   TODO: disable zoom, other options for map; change map when data changes"
  [props]
  (set! (.-imagePath js/L.Icon.Default) "../resources/public/images/")
  (rc/create-class
    {:component-did-mount (leaflet-did-mount props)
     :reagent-render      (fn [props] [:div.map {:id (:id props)}])}))

(defn leaflet-map
  "Helper for showing map when exists and desired."
  [entry show? local-cfg put-fn]
  (let [{:keys [latitude longitude timestamp map-zoom]} entry]
    (when (and show? latitude)
      [leaflet-component {:id     (str "map" timestamp (:query-id local-cfg))
                          :lat    latitude
                          :lon    longitude
                          :zoom   map-zoom
                          :ts     timestamp
                          :put-fn put-fn}])))
