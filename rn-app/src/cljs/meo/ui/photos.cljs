(ns meo.ui.photos
  (:require [meo.ui.shared :refer [view text touchable-highlight cam-roll
                                   scroll map-view mapbox-style-url image]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn photos-page [local put-fn]
  (let [current-map-style (:map-style @local)]
    [scroll {:style {:flex-direction   "column"
                     :padding-top      10
                     :background-color c/light-gray
                     :padding-bottom   10}}

     (for [photo (:edges (:photos @local))]
       (let [node (:node photo)
             loc (:location node)
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
          (when (:latitude loc)
            [map-view {:showUserLocation true
                       :centerCoordinate [(:longitude loc) (:latitude loc)]
                       :scrollEnabled    false
                       :rotateEnabled    false
                       :styleURL         (get mapbox-style-url current-map-style)
                       :style            {:width  160
                                          :max-width 160
                                          :flex   2
                                          :height 160}
                       :zoomLevel        15}])]))

     [text {:style {:color       "#777"
                    :text-align  "center"
                    :font-size   10
                    :font-weight "bold"}}
      (str (dissoc (:photos @local) :edges))]]))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn]
  (let [get-fn #(let [params (clj->js {:first     50
                                       :assetType "All"})
                      photos-promise (.getPhotos cam-roll params)]
                  (.then photos-promise
                         (fn [r]
                           (let [parsed (js->clj r :keywordize-keys true)]
                             (swap! local assoc-in [:photos] parsed)))))
        header-right (fn [_]
                       [touchable-highlight {:on-press get-fn
                                             :style    {:padding-top    8
                                                        :padding-left   12
                                                        :padding-right  12
                                                        :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "show"]])
        opts {:title "Photos" :headerRight header-right}]
    (stack-navigator
      {:photos {:screen (stack-screen (photos-wrapper local put-fn) opts)}})))
