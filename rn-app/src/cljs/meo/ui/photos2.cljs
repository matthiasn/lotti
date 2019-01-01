(ns meo.ui.photos2
  (:require [meo.ui.shared :refer [view text touchable-opacity cam-roll alert
                                   scroll image icon swipeout dimensions]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.colors :as c]
            [meo.helpers :as h]
            [reagent.core :as r]
            [clojure.set :as set]))

(def vw (.-width (.get dimensions "window")))
(def vh (.-height (.get dimensions "window")))

(def rn-snap-carousel (js/require "react-native-snap-carousel"))
(def snap-carousel (r/adapt-react-class (aget rn-snap-carousel "default")))

(defn card [photo put-fn]
  (let [uri (-> photo :node :image :uri)
        node (:node photo)
        loc (:location node)
        lat (:latitude loc)
        lon (:longitude loc)
        img (:image node)
        ts (.floor js/Math (* 1000 (:timestamp node)))
        import (fn [_]
                 (let [filename (str (h/img-fmt ts) "_" (:filename img))
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
                   ;(alert entry)
                   (put-fn [:entry/new entry])))
        hide (fn [_]
               (let [entry {:timestamp  ts
                            :entry-type :hide}]
                 (put-fn [:entry/hide entry])))]
    [view {:style {:flex   1
                   :width  "100%"
                   :height 500}}
     [image {:style  {:width           "100%"
                      :resizeMode      "contain"
                      ;:height          400
                      :height          "80%"
                      :backgroundColor "black"}
             :source {:uri uri}}]
     [text {:style {:color       "#7F7F7F"
                    :text-align  "center"
                    :width       "100%"
                    :font-size   12
                    :font-weight "100"
                    :margin-top  5}}
      (h/format-time ts)]
     [view {:style {:flex            1
                    :width           "100%"
                    :justify-content "space-between"
                    :padding         10
                    :flex-direction  "row"}}
      [touchable-opacity {:on-press hide
                          :style    {:margin           10
                                     :width            150
                                     :background-color "#FF3B30"
                                     :justify-content  "center"
                                     :align-items      "center"
                                     :border-radius    4
                                     :height           40
                                     :flex-direction   "row"}}
       [text {:style {:color     "white"
                      :font-size 20}}
        "hide"]]
      [touchable-opacity {:on-press import
                          :style    {:margin           10
                                     :width            150
                                     :background-color "#4CD964"
                                     :justify-content  "center"
                                     :border-radius    4
                                     :align-items      "center"
                                     :height           40
                                     :flex-direction   "row"}}
       [text {:style {:color     "white"
                      :font-size 20}}
        "import"]]]]))

(defn render-item [put-fn]
  (fn [item]
    (let [item (:item (js->clj item :keywordize-keys true))]
      (r/as-element [card item put-fn]))))

(defn photos-page [local put-fn]
  (let [theme (subscribe [:active-theme])
        all-timestamps (subscribe [:all-timestamps])
        hide-timestamps (subscribe [:hide-timestamps])
        show? #(not (contains?
                      (set/union @all-timestamps @hide-timestamps)
                      (.floor js/Math (* 1000 (:timestamp (:node %))))))]
    (fn [local put-fn]
      (let [bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            data (->> @local :photos :edges (filter show?) vec)]
        [snap-carousel
         {:sliderWidth          vw
          :itemWidth            vw
          :renderItem           (render-item put-fn)
          :data                 data
          :inactiveSlideScale   1
          :inactiveSlideOpacity 1
          :enableMomentum       true
          :backgroundColor      "black"}]))))

(defn photos-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [photos-page local put-fn])))

(defn photos-tab [local put-fn theme]
  (let [get-fn #(let [params (clj->js {:first     1000
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
                         "refresh"]])
        opts {:title            "Photo Import"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (get-fn)
    (stack-navigator
      {:photos3 {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor "black"}})))
