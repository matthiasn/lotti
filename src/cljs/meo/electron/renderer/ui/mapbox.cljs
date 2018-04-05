(ns meo.electron.renderer.ui.mapbox
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [cljs.nodejs :refer [process]]
            [mapbox-gl]
            [reagent.impl.component :as ric]))


(defn mapbox-did-mount [props]
  (fn []
    (info "component did mount")
    (let [{:keys [put-fn local id selected scroll-disabled]} props
          {:keys [latitude longitude]} selected
          opts {:container id
                :zoom      14
                :center    [longitude latitude]
                :style     "mapbox://styles/mapbox/streets-v9"}
          mb-map (mapbox-gl/Map. (clj->js opts))
          marker (-> (mapbox-gl/Marker.)
                     (.setLngLat (clj->js
                                   [longitude
                                    latitude])))
          scroll-zoom (.-scrollZoom mb-map)]
      (swap! local assoc-in [:mb-map] mb-map)
      (aset js/window "mapbox" mb-map)
      (if scroll-disabled
        (.disable scroll-zoom)
        (.enable scroll-zoom))
      (swap! local assoc-in [:marker] marker)
      (.addTo marker mb-map))))

(defn mapbox-cls [props]
  (aset mapbox-gl "accessToken" (:mapbox-token props))
  (r/create-class
    {:component-did-mount          (mapbox-did-mount props)
     :component-will-receive-props (fn [_this props]
                                     (let [props (ric/extract-props props)
                                           {:keys [selected local scroll-disabled]} props
                                           {:keys [latitude longitude]} selected
                                           mb-map (:mb-map @local)
                                           prev-marker (:marker @local)
                                           zoom (.getZoom mb-map)
                                           fly-to {:center [longitude latitude]
                                                   :speed  0.6
                                                   :zoom   zoom}
                                           marker (-> (mapbox-gl/Marker.)
                                                      (.setLngLat (clj->js
                                                                    [longitude
                                                                     latitude])))
                                           scroll-zoom (.-scrollZoom mb-map)]
                                       (if scroll-disabled
                                         (.disable scroll-zoom)
                                         (.enable scroll-zoom))
                                       (swap! local assoc-in [:marker] marker)
                                       (when prev-marker (.remove prev-marker))
                                       (.flyTo mb-map (clj->js fly-to))
                                       (.addTo marker mb-map)))
     :reagent-render               (fn [props]
                                     (let [{:keys [local id]} props]
                                       [:div.mapbox
                                        {:id id}]))}))
