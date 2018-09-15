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

(defn card [photo]
  (let [uri (-> photo :node :image :uri)
        import (fn [idx]
                 (let [node (:node photo)
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
                   ;(put-fn [:entry/new entry])
                   (alert entry)
                   ))]
    [view {:style {:flex         1
                   :width        "100%"
                   :borderRadius 4
                   :height       500
                   :borderWidth  1}}
     [image {:style  {:width           "100%"
                      :resizeMode      "contain"
                      :height          400
                      ;:height     "80%"
                      :backgroundColor "black"}
             :source {:uri uri}}]
     [touchable-opacity {:on-press import
                         :style    {:margin         10
                                    :display        "flex"
                                    :flex-direction "row"}}
      [text {:style {:color       "#0078e7"
                     :font-size   30
                     :margin-left 25}}
       "import"]]]))

(defn render-item [item]
  (let [item (:item (js->clj item :keywordize-keys true))]
    (r/as-element [card item])))

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
            data (->> @local :photos :edges (filter show?) vec)
            #_#_swipe-right (fn [idx]
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
                                (put-fn [:entry/new entry])))
            #_#_swipe-left (fn [idx]
                             (let [photo (nth cards idx)
                                   node (:node photo)
                                   ts (.floor js/Math (* 1000 (:timestamp node)))
                                   entry {:timestamp  ts
                                          :entry-type :hide}]
                               (put-fn [:entry/hide entry])))]
        [snap-carousel
         {:sliderWidth     vw
          :itemWidth       vw
          :renderItem      render-item
          :data            data
          :backgroundColor "#222"}]))))

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
                         "cam roll"]])
        opts {:title            "Photos"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (get-fn)
    (stack-navigator
      {:photos3 {:screen (stack-screen (photos-wrapper local put-fn) opts)}}
      {:cardStyle {:backgroundColor "black"}})))
