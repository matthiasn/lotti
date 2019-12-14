(ns meins.electron.renderer.ui.geo.locations-map
  (:require ["mapbox-gl" :refer [LngLat LngLatBounds Map Marker Popup] :as mapbox-gl]
            ["moment" :as moment]
            [cljs-bean.core :refer [->js]]
            [markdown.core :as mc]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.briefing.calendar :as ebc]
            [meins.electron.renderer.ui.geo.queries :as qry]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.impl.component :as ric]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn infinite-cal-search [local]
  (let [on-select (fn [ev]
                    (let [selected (js->clj ev :keywordize-keys true)
                          start (h/ymd (:start selected))
                          end (h/ymd (:end selected))
                          sel {:start start
                               :end   end}]
                      (swap! local assoc-in [:selected] sel)
                      (when (= (:eventType selected) 3)
                        (swap! local merge {:from start
                                            :to   end})
                        (qry/queries local))))]
    (fn [local]
      (let [selected (:selected @local)]
        [:div.infinite-cal-search
         [ebc/infinite-cal-range-adapted
          {:width          "100%"
           :height         150
           :onSelect       on-select
           :theme          {:weekdayColor "#666"
                            :headerColor  "#778"}
           :displayOptions {:showHeader   false
                            :showWeekdays true}
           :rowHeight      32
           :selected       selected}]]))))

(def points-cfg
  {:id     "points"
   :type   "circle"
   :source "locations"
   :paint  {:circle-radius 4
            :circle-color  ["match"
                            ["get" "activity"]
                            "on_foot" "green"
                            "walking" "darkgreen"
                            "running" "red"
                            "in_vehicle" "blue"
                            "on_bicycle" "orange"
                            "still" "#AAA"
                            "#888"]}})

(def lines-cfg
  {:id     "lines"
   :type   "line"
   :source "lines"
   :layout {:line-join "round"
            :line-cap  "round"}
   :paint  {:line-width   5
            :line-opacity 0.5
            :line-color   ["get" "color"]}})

(def img-points-cfg
  {:id     "images"
   :type   "circle"
   :source "images"
   :paint  {:circle-radius         3
            :circle-color          "#FF818C"
            :circle-stroke-width   1
            :circle-opacity        0.6
            :circle-stroke-opacity 0.6
            :circle-stroke-color   "#EF4E59"}})

(def icon-url "/Users/mn/github/meins/resources/public/map/C2_active_red.png")

(def img-icons-cfg
  {:id     "img-icons"
   :type   "symbol"
   :source "image-icons"
   :layout {:icon-image "img-icon"
            :icon-size  0.35}})

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
   :mineral           "mapbox://styles/matthiasn/ck0o3ac0d0ab51cp6o565lvx0"
   :le-shine          "mapbox://styles/matthiasn/ck11d7tl20gw01cpdtfmr1kkz"
   :satellite         "mapbox://styles/mapbox/satellite-v9"
   :satellite-streets "mapbox://styles/mapbox/satellite-streets-v11"})

(defn add-layers [mb-map]
  ;(.addLayer mb-map (clj->js points-cfg))
  (.addLayer mb-map (clj->js img-points-cfg))
  (.addLayer mb-map (clj->js img-icons-cfg))
  #_(.addLayer mb-map (clj->js buildings-cfg)))

(defn zoom-bounds [local features _]
  (let [bounds (LngLatBounds.)
        mb-map (:mb-map @local)]
    (doseq [feat features]
      (let [[lng lat] (-> feat :geometry :coordinates)]
        (.extend bounds (LngLat. lng lat))))
    (.fitBounds mb-map bounds (->js {:padding 50}))))

(defn activity-color [activity]
  (case activity
    "on_foot" "green"
    "walking" "darkgreen"
    "running" "red"
    "in_vehicle" "blue"
    "on_bicycle" "orange"
    "still" "turquoise"
    "deeppink"))

(defn line-feature-mapper [line-data]
  (let [color (activity-color (-> line-data :properties :activity))]
    (assoc-in line-data [:properties :color] color)))

(defn line-data [line-res]
  (let [line-features (map line-feature-mapper line-res)]
    {:type     "FeatureCollection"
     :features line-features}))

(defn line-source [line-res]
  {:type "geojson"
   :data (line-data line-res)})

(defn img-html [url md ts locale]
  (info :img-html url ts (keyword locale))
  (str "<div class='entry map-entry'>"
       "<img src='" url "'></img>"
       "<time>" (h/localize-datetime (moment ts) locale) "</time>"
       "<p>" (:html (mc/md-to-html-string* md {})) "</p>"
       "</div>"))

(defn img-data [img-features]
  {:type     "FeatureCollection"
   :features img-features})

(defn ->img-features [features]
  (filter #(-> % :properties :entry :img_file) features))

(defn img-markers [mb-map img-features]
  (doseq [feat img-features]
    (let [coords (-> feat :geometry :coordinates)
          el (js/document.createElement "div")]
      (aset el "className" "img-marker")
      (-> (Marker. el)
          (.setLngLat (->js (take 2 coords)))
          (.setPopup (-> (Popup. (->js {:offset 25}))
                         (.setHTML "<div>foooo</div")))
          (.addTo mb-map))
      (info coords))))

(defn map-did-mount [props]
  (let [gql-res (subscribe [:gql-res])
        cfg (subscribe [:cfg])
        feature-subs (reaction (get-in @gql-res [:locations-map :data :locations_by_days]))]
    (fn []
      (let [{:keys [local data]} props
            {:keys [zoom lat lng style]} @local
            features (:locations_by_days data)
            line-res (:lines_by_days data)
            style (get styles style)
            locale (:locale @cfg :en)
            opts {:container "heatmap"
                  :zoom      zoom
                  :center    [lng lat]
                  :pitch     0
                  :style     style}
            mb-map (Map. (clj->js opts))
            img-features (->img-features features)
            img-geojson {:type "geojson"
                         :data (img-data img-features)}
            img-icons-geojson {:type "geojson"
                               :data (img-data [])}
            loaded (fn []
                     (.addSource mb-map "images" (->js img-geojson))
                     (.addSource mb-map "image-icons" (->js img-icons-geojson))
                     (.addSource mb-map "lines" (->js (line-source line-res)))
                     ;(img-markers mb-map img-features)
                     (.addLayer mb-map (->js lines-cfg))
                     (.addLayer mb-map (->js img-points-cfg))
                     (.loadImage mb-map icon-url (fn [_err img]
                                                   (.addImage mb-map "img-icon" img))
                                 (.addLayer mb-map (->js img-icons-cfg))))
            hide-gallery #(swap! local assoc-in [:gallery] false)
            popup (Popup. (->js {:closeButton  false
                                 :offset       5
                                 :closeOnClick false}))
            mouse-leave (fn []
                          (let [canvas (.getCanvas mb-map)]
                            (.remove popup)
                            (aset canvas "style" "cursor" "")))
            mouse-enter-img (fn [e]
                              (let [canvas (.getCanvas mb-map)
                                    feature (aget e "features" 0)
                                    coords (aget feature "geometry" "coordinates")
                                    entry (aget feature "properties" "entry")
                                    entry (js/JSON.parse entry)
                                    img_file (.-img_file entry)
                                    md (.-md entry)
                                    ts (.-timestamp entry)
                                    url (str "file://" (h/thumbs-512 img_file))
                                    html (img-html url md ts locale)]
                                (aset canvas "style" "cursor" "pointer")
                                (-> popup
                                    (.setLngLat coords)
                                    (.setHTML html)
                                    (.addTo mb-map))))
            zoom-bounds (partial zoom-bounds local features)
            photo-cycle (fn []
                          (let [img-features (->img-features @feature-subs)
                                cnt (count img-features)
                                idx (rem (:photo-idx @local) cnt)
                                idx (if (neg? idx)
                                      (+ idx cnt)
                                      idx)]
                            (.remove popup)
                            (when (and (not (neg? idx)) (< idx cnt) (:popup @local))
                              (let [feature (nth img-features idx)
                                    coords (->> feature :geometry :coordinates (take 2))
                                    entry (-> feature :properties :entry)
                                    img_file (:img_file entry)
                                    md (:md entry)
                                    ts (:timestamp entry)
                                    url (str "file://" (h/thumbs-512 img_file))
                                    html (img-html url md ts locale)
                                    img-geojson (->js (img-data [feature]))]
                                (.setData (.getSource mb-map "image-icons") img-geojson)
                                (js/setTimeout #(-> popup
                                                    (.setLngLat (->js coords))
                                                    (.setHTML html)
                                                    (.addTo mb-map))
                                               100)
                                (.easeTo mb-map (->js {:center coords}))))
                            (info :photo-idx idx (neg? idx) cnt)))]
        (swap! local assoc-in [:mb-map] mb-map)
        (aset js/window "heatmap" mb-map)
        (.on mb-map "load" loaded)
        (.on mb-map "zoomstart" hide-gallery)
        (.on mb-map "zoomend" (fn [e]
                                (let [coords {:zoom (aget e "target" "transform" "_zoom")
                                              :lat  (aget e "target" "transform" "_center" "lat")
                                              :lng  (aget e "target" "transform" "_center" "lng")}]
                                  (swap! local merge coords))))
        (.on mb-map "mouseenter" "images" mouse-enter-img)
        (.on mb-map "mouseleave" "images" mouse-leave)
        (js/setTimeout zoom-bounds 1000)
        (add-watch local :photo-idx photo-cycle)))))

(defn will-receive-props [_this props]
  (let [{:keys [local data]} (ric/extract-props props)
        mb-map (:mb-map @local)
        features (:locations_by_days data)
        img-features (->img-features features)
        img-geojson (->js (img-data img-features))
        lines (->js (line-data (:lines_by_days data)))
        zoom-bounds (partial zoom-bounds local features)]
    (when-let [line-src (.getSource mb-map "lines")]
      (.setData line-src lines))
    (when-let [img-src (.getSource mb-map "images")]
      (.setData img-src img-geojson)
      ;(.setData (.getSource mb-map "image-icons") img-geojson)
      ;(img-markers mb-map img-features)
      (js/setTimeout zoom-bounds 1000))))

(defn map-cls [props]
  (info "map-cls")
  (r/create-class
    {:component-did-mount          (map-did-mount props)
     :component-will-receive-props will-receive-props
     :reagent-render               (fn [props]
                                     (let [{:keys []} props]
                                       [:div#heatmap {:style {:width            "100vw"
                                                              :height           "100vh"
                                                              :background-color "#333"}}]))}))

(defn map-view [props]
  (info "map-view")
  ^{:key (:style @(:local props))}
  [map-cls props])

(defn map-render [local]
  (let [backend-cfg (subscribe [:backend-cfg])
        gql-res (subscribe [:gql-res])
        data (reaction (get-in @gql-res [:locations-map :data]))]
    (fn []
      (let [mapbox-token (:mapbox-token @backend-cfg)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [:div.heatmap
            [:div.ctrl
             [infinite-cal-search local]
             [:select {:value     (:style @local)
                       :style     {:padding-right 20}
                       :on-change (fn [ev]
                                    (let [k (keyword (h/target-val ev))]
                                      (swap! local assoc :style k)))}
              (for [[k _style-url] styles]
                ^{:key k}
                [:option k])]]
            [map-view {:local local
                       :data  @data}]]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))

(defn locations-map []
  (let [local (r/atom {:zoom      5
                       :lng       10.1
                       :lat       53.56
                       :photo-idx 0
                       :popup     false
                       :style     :le-shine
                       :from      (h/ymd (stc/now))
                       :to        (h/ymd (stc/now))})
        render (fn [_props] [map-render local])
        keydown (fn [ev]
                  (let [key-code (.. ev -keyCode)]
                    (when (.-metaKey ev)
                      (when (= key-code 37)
                        (swap! local assoc :popup true)
                        (swap! local update :photo-idx dec))
                      (when (= key-code 39)
                        (swap! local assoc :popup true)
                        (swap! local update :photo-idx inc))
                      (when (= key-code 40)
                        (swap! local assoc :popup false))
                      (.stopPropagation ev))))
        cleanup (fn []
                  (emit [:gql/remove {:query-id :locations-map}])
                  (.removeEventListener js/document "keydown" keydown))]
    (.addEventListener js/document "keydown" keydown)
    (qry/queries local)
    (r/create-class {:component-will-unmount cleanup
                     :reagent-render         render})))
