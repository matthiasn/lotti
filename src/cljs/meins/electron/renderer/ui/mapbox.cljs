(ns meins.electron.renderer.ui.mapbox
  (:require ["mapbox-gl" :as mapbox-gl]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.impl.component :as ric]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn mapbox-did-mount [props]
  (let [cfg (subscribe [:cfg])
        satellite (reaction (:satellite-view @cfg))]
    (fn []
      (info "component did mount")
      (let [{:keys [local id selected scroll-disabled opts]} props
            {:keys [latitude longitude]} selected
            style (if @satellite
                    "mapbox://styles/mapbox/satellite-v9"
                    "mapbox://styles/mapbox/streets-v9")
            opts (merge
                   {:container id
                    :zoom      14
                    :center    [longitude latitude]
                    :style     style}
                   opts)
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
        (when (and latitude longitude)
          (swap! local assoc-in [:marker] marker)
          (.addTo marker mb-map))))))

(defn component-will-receive-props [_this props]
  (let [props (ric/extract-props props)
        {:keys [selected local scroll-disabled]} props
        {:keys [latitude longitude]} selected
        mb-map (:mb-map @local)
        prev-marker (:marker @local)
        ease-to {:center [longitude latitude]
                 :speed  0.6}
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
    (when (and latitude longitude)
      (.easeTo mb-map (clj->js ease-to))
      (.addTo marker mb-map))))

(defn render [props]
  (let [{:keys [id selected]} props
        rm-location #(emit [:entry/update
                            (merge selected
                                   {:longitude 0
                                    :latitude  0})])]
    [:div.mapbox {:id id}
     [:i.fas.fa-trash-alt {:on-click rm-location}]]))

(defn mapbox-cls [props]
  (aset mapbox-gl "accessToken" (:mapbox-token props))
  (r/create-class
    {:component-did-mount          (mapbox-did-mount props)
     :component-will-receive-props component-will-receive-props
     :reagent-render               render}))
