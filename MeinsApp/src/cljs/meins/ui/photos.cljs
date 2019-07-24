(ns meins.ui.photos
  (:require [meins.ui.shared :refer [view text touchable-opacity alert
                                     scroll image dimensions]]
            [re-frame.core :refer [reg-sub subscribe]]
            ["@matthiasn/cameraroll" :as cam-roll]
            ["react-native-super-grid" :as rn-super-grid]
            [meins.ui.colors :as c]
            [meins.helpers :as h]
            [reagent.core :as r]
            [meins.ui.db :refer [emit]]
            [clojure.set :as set]
            [meins.ui.db :as uidb]
            [matthiasn.systems-toolbox.component :as stc]))

(def flat-grid (r/adapt-react-class (.-FlatGrid rn-super-grid)))
(def screen-width (.-width (.get dimensions "window")))
(def img-dimension (js/Math.floor (/ (- screen-width 10) 3)))

(defn card [_]
  (let []
    (fn [item]
      (let [json (js/JSON.stringify (.-item item))
            parsed (js->clj (js/JSON.parse json) :keywordize-keys true)
            {:keys [latitude longitude uri timestamp fileName]} parsed
            filename (str (h/img-fmt timestamp) "_" fileName)
            import (fn [_]
                     (let [entry {:latitude  latitude
                                  :longitude longitude
                                  :md        ""
                                  :tags      #{"#import"}
                                  :perm_tags #{"#photo"}
                                  :mentions  #{}
                                  :media     {:image {:uri uri}}
                                  :img_file  filename
                                  :timestamp timestamp}]
                       (emit [:entry/new entry])))
            hide (fn [_]
                   (let [entry {:timestamp  timestamp
                                :entry-type :hide}]
                     (emit [:entry/hide entry])))]
        [touchable-opacity {:on-press import
                            :style    {:flex 1}}
         [image {:style  {:width           img-dimension
                          :height          img-dimension
                          :resizeMode      "cover"
                          :backgroundColor "black"}
                 :source {:uri uri}}]]))))

(defn photos-tab []
  (let [realm-db @uidb/realm-db
        local (r/atom {:last-updated 0})
        update-local #(swap! local assoc :last-updated (stc/now))
        refresh (fn [_]
                  (emit [:photos/import {:n 1000}])
                  (js/setTimeout update-local 1000))]
    (refresh nil)
    (fn []
      (let [items (some-> realm-db
                          (.objects "Image")
                          (.sorted "timestamp" true)
                          (.slice 0 1000))]
        @local
        [view {:width  "100%"
               :height "100%"}
         [flat-grid
          {:itemDimension img-dimension
           :items         items
           :style         {:flex             1
                           :background-color "black"
                           :margin-top       50}
           :on-refresh    refresh
           :refreshing    false
           :spacing       2
           :renderItem    (fn [x] (r/as-element [card x]))}]]))))
