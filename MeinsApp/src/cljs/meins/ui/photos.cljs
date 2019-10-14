(ns meins.ui.photos
  (:require ["react-native-super-grid" :as rn-super-grid]
            [cljs-bean.core :refer [->clj ->js bean]]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.helpers :as h]
            [meins.ui.db :as uidb :refer [emit]]
            [meins.ui.icons.misc :as icns]
            [meins.ui.shared :refer [dimensions image text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]))

(def flat-grid (r/adapt-react-class (.-FlatGrid rn-super-grid)))
(def screen-width (.-width (.get dimensions "window")))
(def img-dimension (js/Math.floor (/ (- screen-width 20) 3)))

(defn card [refresh item]
  (let [json (js/JSON.stringify (.-item item))
        parsed (js->clj (js/JSON.parse json) :keywordize-keys true)
        {:keys [latitude longitude uri timestamp fileName imported]} parsed
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
                   (.write @uidb/realm-db #(aset (.-item item) "imported" true))
                   (refresh nil)
                   (emit [:photos/import {:n 10000}])
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
             :source {:uri uri}}]
     [view {:style {:position :absolute
                    :right    9
                    :top      10}}
      (when imported
        [icns/photo-checkmark-icon 26])]]))

(defn button [{:keys [label bg font]}]
  [view {:style {:background-color bg
                 :width            92
                 :height           36
                 :align-items      :center
                 :justify-content  :center
                 :border-color     "#4A546E"
                 :borderWidth      1
                 :border-radius    18}}
   [text {:style {:font-size   15
                  :height      22
                  :line-height 22
                  :font-family font
                  :text-align  :center
                  :color       "white"}}
    label]])

(defn photos-tab []
  (let [realm-db @uidb/realm-db
        theme (subscribe [:active-theme])
        local (r/atom {:last-updated 0})
        update-local #(swap! local assoc :last-updated (stc/now))
        refresh (fn [_]
                  (emit [:photos/import {:n 1000}])
                  (js/setTimeout update-local 1000))]
    (refresh nil)
    (fn []
      (let [bg (get-in styles/colors [:list-bg @theme])
            items (some-> realm-db
                          (.objects "Image")
                          (.sorted "timestamp" true))]
        @local
        [view {:style {:width  "100%"
                       :height "100%"}}
         [view {:style {:display          :flex
                        :flex-direction   :row
                        :justify-content  :center
                        :background-color "rgba(44,50,70,0.9)"
                        :padding-top      52
                        :padding-bottom   15}}
          [button {:label "ADDED"
                   :bg    "#4A546E"
                   :font  :Montserrat-SemiBold}]
          [view {:style {:width 18}}]
          [button {:label "ALL"
                   :font  :Montserrat-Regular}]]
         [flat-grid
          {:itemDimension img-dimension
           :items         items
           :style         {:flex             1
                           :background-color bg}
           :on-refresh    refresh
           :refreshing    false
           :spacing       4
           :renderItem    (fn [x] (r/as-element [card refresh x]))}]]))))
