(ns meo.ui.photos
  (:require [meo.ui.shared :refer [view text touchable-opacity cam-roll
                                   scroll image icon swipeout]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]
            [meo.helpers :as h]
            [meo.ui.shared :as sh]
            [reagent.core :as r]))

(def react-native-deck-swiper (js/require "react-native-deck-swiper"))
(def deck-swiper (r/adapt-react-class (aget react-native-deck-swiper "default")))

(defn card [photo]
  (let [uri (-> photo :node :image :uri)]
    [view {:style {:flex            1
                   :width           "100%"
                   :backgroundColor "black"
                   :borderRadius    4
                   :borderWidth     1}}
     [image {:style  {:width      "100%"
                      :resizeMode "contain"
                      ;:height 400
                      :height     "80%"}
             :source {:uri uri}}]]))

(defn render-card [item]
  (let [item (js->clj item :keywordize-keys true)]
    (r/as-element [card item])))

(defn photos-page [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [local put-fn]
      (let [bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            cards (->> @local :photos :edges vec)
            swipe-right (fn [idx]
                          (let [photo (nth cards idx)
                                node (:node photo)
                                loc (:location node)
                                lat (:latitude loc)
                                lon (:longitude loc)
                                img (:image node)
                                ts (.floor js/Math (* 1000 (:timestamp node)))
                                filename (str (h/img-fmt ts) "_" (:filename img))
                                entry {:latitude  lat
                                       :longitude lon
                                       :location  loc
                                       :md        ""
                                       :tags      #{"#import"}
                                       :perm_tags #{"#photo"}
                                       :mentions  #{}
                                       :media     (dissoc node :location)
                                       :img_file  filename
                                       :timestamp ts}]
                            (put-fn [:entry/new entry])))]
        [deck-swiper
         {:cards                cards
          :onSwipedRight        swipe-right
          :onSwipedAll          #(sh/alert (str :onSwipedAll %))
          :cardIndex            0
          :renderCard           render-card
          :cardHorizontalMargin 0
          :cardVerticalMargin   0
          :backgroundColor      "black"}]))))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn theme]
  (let [get-fn #(let [params (clj->js {:first     100
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
        opts {:title            "Photos"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (get-fn)
    (stack-navigator
      {:photos3 {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor "black"}})))
