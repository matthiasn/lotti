(ns meo.ui.photos
  (:require [meo.ui.shared :refer [view text touchable-opacity cam-roll
                                   map-view mapbox-style-url point-annotation
                                   scroll image]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]))

(defn photos-page [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [local put-fn]
      (let [current-map-style (:map-style @local)
            bg (get-in c/colors [:list-bg @theme])]
        [scroll {:style {:flex-direction   "column"
                         :padding-top      10
                         :background-color bg
                         :padding-bottom   10}}

         (for [photo (:edges (:photos @local))]
           (let [node (:node photo)
                 loc (:location node)
                 lat (:latitude loc)
                 lon (:longitude loc)
                 img (:image node)]
             ^{:key (:uri img)}
             [view {:style {:padding-top    10
                            :padding-bottom 10
                            :margin-bottom  10
                            :width          "100%"
                            :display        :flex
                            :flex-direction :row}}
              [image {:style  {:width      240
                               :height     160
                               :max-height 160}
                      :source {:uri (:uri img)}}]
              (when lat
                [map-view {;:showUserLocation true
                           :centerCoordinate [lon lat]
                           :scrollEnabled    false
                           :rotateEnabled    false
                           :styleURL         (get mapbox-style-url current-map-style)
                           :style            {:width     160
                                              :max-width 160
                                              :flex      2
                                              :height    160}
                           :zoomLevel        15}
                 [point-annotation {:coordinate [lon lat]}
                  [view {:style {:width           24
                                 :height          24
                                 :alignItems      "center"
                                 :justifyContent  "center"
                                 :backgroundColor "white"
                                 :borderRadius    12}}
                   [view {:style {:width           24
                                  :height          24
                                  :backgroundColor "orange"
                                  :borderRadius    12
                                  :transform       [{:scale 0.7}]}}]]]])]))

         [text {:style {:color       "#777"
                        :text-align  "center"
                        :font-size   10
                        :font-weight "bold"}}
          (str (dissoc (:photos @local) :edges))]]))))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn theme]
  (let [get-fn #(let [params (clj->js {:first     50
                                       :assetType "All"})
                      photos-promise (.getPhotos cam-roll params)]
                  (.then photos-promise
                         (fn [r]
                           (let [parsed (js->clj r :keywordize-keys true)]
                             (swap! local assoc-in [:photos] parsed)))))
        header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        list-bg (get-in c/colors [:list-bg @theme])
        header-right (fn [_]
                       [touchable-opacity {:on-press get-fn
                                           :style    {:padding-top    8
                                                      :padding-left   12
                                                      :padding-right  12
                                                      :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "show"]])
        opts {:title            "Photos"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (stack-navigator
      {:photos {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor list-bg}})))
