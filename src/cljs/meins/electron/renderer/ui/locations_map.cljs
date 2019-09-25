(ns meins.electron.renderer.ui.locations-map
  (:require [reagent.core :as r]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [cljs.nodejs :refer [process]]
            [cljs-bean.core :refer [bean ->clj ->js]]
            ["mapbox-gl" :refer [Map Popup LngLat LngLatBounds] :as mapbox-gl]
            ["moment" :as moment]
            [markdown.core :as mc]
            [meins.electron.renderer.ui.entry.carousel :as carousel]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.graphql :as gql]
            [cljs.tools.reader.edn :as edn]
            [clojure.pprint :as pp]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.electron.renderer.ui.entry.briefing.calendar :as ebc]
            [venia.core :as v]))

(defn queries [local]
  (let [{:keys [from to]} @local
        q1 [:locations_by_days
            {:from from
             :to   to}
            [:type
             [:geometry [:type
                         :coordinates]]
             [:properties [:activity
                           :data
                           [:entry [:md
                                    :timestamp
                                    :img_file
                                    :img_rel_path]]
                           :accuracy
                           :timestamp
                           :entry_type]]]]
        q2 [:lines_by_days
            {:from     from
             :to       to
             :accuracy 250}
            [:type
             [:geometry [:type
                         :coordinates]]
             [:properties [:activity]]]]
        gql (v/graphql-query {:venia/queries [{:query/data q1}
                                              {:query/data q2}]})
        q {:id       :locations-map
           :q        gql
           :res-hash nil
           :prio     15}]
    (emit [:gql/query q])))

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
                        (queries local))))]
    (fn [local]
      (let [selected (:selected @local)]
        [:div.infinite-cal-search
         [ebc/infinite-cal-range-adapted
          {:width     "100%"
           :height    200
           :onSelect  on-select
           :theme     {:weekdayColor "#666"
                       :headerColor  "#778"}
           :rowHeight 40
           :selected  selected}]]))))

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

(def img-points-cfg
  {:id     "images"
   :type   "circle"
   :source "images"
   :paint  {:circle-radius 6
            :circle-color  "#C9B037"}})

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
   :satellite         "mapbox://styles/mapbox/satellite-v9"
   :satellite-streets "mapbox://styles/mapbox/satellite-streets-v11"})

(defn add-layers [mb-map]
  ;(.addLayer mb-map (clj->js points-cfg))
  (.addLayer mb-map (clj->js img-points-cfg))
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

(defn add-lines [mb-map lines-res]
  (let [line-features (map line-feature-mapper lines-res)
        layer-data {:id     "lines"
                    :type   "line"
                    :source {:type "geojson"
                             :data {:type     "FeatureCollection"
                                    :features line-features}}
                    :layout {:line-join "round"
                             :line-cap  "round"}
                    :paint  {:line-width   6
                             :line-opacity 0.6
                             :line-color   ["get" "color"]}}]
    (.addLayer mb-map (->js layer-data))))

(defn img-url [url md]
  (str "<div class='entry map-entry'>"
       "<img style='width:100%' src='" url "'></img>"
       "<p>" (:html (mc/md-to-html-string* md {})) "</p>"
       "</div>"))

(defn map-did-mount [props]
  (fn []
    (let [{:keys [local data]} props
          {:keys [zoom lat lng]} @local
          features (:locations_by_days data)
          line-features (:lines_by_days data)
          opts {:container "heatmap"
                :zoom      zoom
                :center    [lng lat]
                :pitch     0
                :style     (:mineral styles)}
          mb-map (Map. (clj->js opts))
          img-features (filter #(-> % :properties :entry :img_file) features)
          img-data {:type "geojson"
                    :data {:type     "FeatureCollection"
                           :features img-features}}
          loaded (fn []
                   (.addSource mb-map "images" (clj->js img-data))
                   (time (add-lines mb-map line-features))
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
                          (-> popup
                              (.setLngLat coords)
                              (.setHTML html)
                              (.addTo mb-map))))
          mouse-enter-img (fn [e]
                            (let [canvas (.getCanvas mb-map)
                                  feature (aget e "features" 0)
                                  coords (aget feature "geometry" "coordinates")
                                  entry (aget feature "properties" "entry")
                                  entry (js/JSON.parse entry)
                                  img_file (.-img_file entry)
                                  md (.-md entry)
                                  url (str "file://" (h/thumbs-512 img_file))
                                  html (img-url url md)]
                              (aset canvas "style" "cursor" "pointer")
                              (-> popup
                                  (.setLngLat coords)
                                  (.setHTML html)
                                  (.addTo mb-map))))
          zoom-bounds (partial zoom-bounds local features)]
      (swap! local assoc-in [:mb-map] mb-map)
      (aset js/window "heatmap" mb-map)
      (.on mb-map "load" loaded)
      (.on mb-map "zoomstart" hide-gallery)
      (.on mb-map "zoomend" (fn [e]
                              (let [coords {:zoom (aget e "target" "transform" "_zoom")
                                            :lat  (aget e "target" "transform" "_center" "lat")
                                            :lng  (aget e "target" "transform" "_center" "lng")}]
                                (swap! local merge coords))))
      ;(.on mb-map "mouseenter" "points" mouse-enter)
      ;(.on mb-map "mouseleave" "points" mouse-leave)
      (.on mb-map "mouseenter" "images" mouse-enter-img)
      (.on mb-map "mouseleave" "images" mouse-leave)
      (js/setTimeout zoom-bounds 1000))))

(defn map-cls [props]
  (r/create-class
    {:component-did-mount (map-did-mount props)
     :reagent-render      (fn [props]
                            (let [{:keys [local]} props]
                              [:div#heatmap {:style {:width            "100vw"
                                                     :height           "100vh"
                                                     :background-color "#333"}}]))}))

(defn map-view [props]
  (info "Location map render")
  ^{:key (stc/make-uuid)}
  [map-cls props])

(defn map-render [local]
  (let [backend-cfg (subscribe [:backend-cfg])
        gql-res (subscribe [:gql-res])
        data (reaction (get-in @gql-res [:locations-map :data]))]
    (fn []
      (let [mapbox-token (:mapbox-token @backend-cfg)
            points (:locations_by_days @data)]
        (aset mapbox-gl "accessToken" mapbox-token)
        (if mapbox-token
          [:div.flex-container
           [:div.heatmap
            [:div.ctrl
             [infinite-cal-search local]
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
             [:button {:on-click (partial zoom-bounds local points)
                       :style    {:margin-left 20}}
              "fit bounds"]]
            [map-view {:local local
                       :data  @data}]]]
          [:div.flex-container
           [:div.error
            [:h1
             [:i.fas.fa-exclamation]
             "mapbox access token not found"]]])))))

(defn locations-map []
  (let [local (r/atom {:zoom 5
                       :lng  10.1
                       :lat  53.56
                       :from (h/ymd (stc/now))
                       :to   (h/ymd (stc/now))})
        render (fn [props] [map-render local])
        cleanup #(emit [:gql/remove {:query-id :locations-map}])]
    (queries local)
    (r/create-class {:component-will-unmount cleanup
                     :reagent-render         render})))
