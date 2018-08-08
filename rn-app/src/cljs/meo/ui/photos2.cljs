(ns meo.ui.photos2
  (:require [meo.ui.shared :refer [view text touchable-opacity cam-roll
                                   scroll image icon swipeout]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]
            [meo.helpers :as h]
            [meo.utils.parse :as p]
            [meo.ui.shared :as shared]
            [reagent.core :as r]))

(def react-native-swipe-cards (js/require "react-native-swipe-cards"))
(def swipe-cards (r/adapt-react-class (aget react-native-swipe-cards "default")))

(defn card [img]
  [view {:style {:background-color "black"}}
   [image {:style  {:width  400
                    :height 400}
           :source {:uri (:uri img)}}]])

(defn render-card [put-fn]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)]
      (r/as-element [card item]))))

(defn photos-page [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [local put-fn]
      (let [bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            cards (->> @local :photos :edges (map #(-> % :node :image)))]
        [view {:style {:background-color "black"
                       :height "100%"}}
         [swipe-cards {:style          {:flex-direction "column"}
                       :cards          (clj->js cards)
                       ;:handleYup      #(shared/alert "yup")
                       ;:handleNope     #(shared/alert "nope")
                       :onClickHandler #()
                       :renderCard     (render-card put-fn)
                       :loop           true}]]))))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn theme]
  (let [get-fn #(let [params (clj->js {:first     50
                                       :assetType "Photos"})
                      photos-promise (.getPhotos cam-roll params)]
                  (.then photos-promise
                         (fn [r]
                           (let [parsed (js->clj r :keywordize-keys true)]
                             (swap! local assoc-in [:photos] parsed)))))
        header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        header-right (fn [_]
                       [touchable-opacity {:on-press get-fn
                                           :style    {:padding-top    8
                                                      :padding-left   12
                                                      :padding-right  12
                                                      :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "cam roll"]])
        opts {:title            "Photos2"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (stack-navigator
      {:photos2 {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor "black"}})))
