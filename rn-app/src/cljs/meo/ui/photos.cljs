(ns meo.ui.photos
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight cam-roll
                                   scroll map-view mapbox-style-url image]]
            [re-frame.core :refer [reg-sub subscribe]]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn photos-page [local put-fn]
  [scroll {:style {:flex-direction "column"
                   :padding-top    10
                   :padding-bottom 10}}

   [view {:style {:flex-direction "row"
                  :padding-top    10
                  :padding-bottom 10
                  :padding-left   10
                  :padding-right  10}}
    [touchable-highlight
     {:style    defaults
      :on-press #(let [params (clj->js {:first     20
                                        :assetType "All"})
                       photos-promise (.getPhotos cam-roll params)]
                   (.then photos-promise
                          (fn [r]
                            (let [parsed (js->clj r :keywordize-keys true)]
                              (swap! local assoc-in [:photos] parsed)))))}
     [text {:style {:color       "white"
                    :text-align  "center"
                    :font-weight "bold"}}
      "get photos"]]]

   (for [photo (:edges (:photos @local))]
     (let [node (:node photo)
           loc (:location node)
           img (:image node)]
       [view {:style {:padding-top    10
                      :padding-bottom 10
                      :margin-bottom  10
                      :width          "100%"
                      :display        :flex
                      :flex-direction :row}}
        [image {:style  {:width     160
                         :height    160
                         :max-width 160
                         :max-height 160}
                :source {:uri (:uri img)}}]
        (when (:latitude loc)
          [map-view {:showUserLocation true
                     :centerCoordinate [(:longitude loc) (:latitude loc)]
                     :scrollEnabled    false
                     :rotateEnabled    false
                     :styleURL         (get mapbox-style-url (:map-style @local))
                     :style            {:width  200
                                        :flex   2
                                        :height 160}
                     :zoomLevel        15}])
        #_[text {:style {:color       "#777"
                         :text-align  "center"
                         :width       150
                         :font-size   10
                         :font-weight "bold"}}
           (str (:uri img))]]))

   [text {:style {:color       "#777"
                  :text-align  "center"
                  :font-size   10
                  :font-weight "bold"}}
    (str (dissoc (:photos @local) :edges))]])
