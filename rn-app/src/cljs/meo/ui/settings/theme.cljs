(ns meo.ui.settings.theme
  (:require [meo.ui.colors :as c]
            [meo.ui.shared :refer [view scroll picker picker-item map-view cam text mapbox-style-url icon]]
            [meo.ui.settings.common :as sc :refer [settings-icon]]
            [re-frame.core :refer [subscribe]]
            [cljs.tools.reader.edn :as edn]))

(defn theme-settings-wrapper [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [scroll {}
          [picker {:selected-value  @theme
                   :itemStyle       {:color text-color}
                   :on-value-change (fn [v idx]
                                      (let [style (keyword v)]
                                        (put-fn [:theme/active style])))}
           [picker-item {:label "light theme"
                         :value :light}]
           [picker-item {:label "dark theme"
                         :value :dark}]]

          [view {:style {:flex-direction "column"
                         :width          "100%"}}
           [map-view {:showUserLocation true
                      :centerCoordinate [9.95 53.55]
                      :styleURL         (get mapbox-style-url (:map-style @local))
                      :style            {:width         "100%"
                                         :flex          2
                                         :height        300
                                         :margin-bottom 10}
                      :zoomLevel        10}]]
          [picker {:selected-value  (:map-style @local)
                   :itemStyle       {:color text-color}
                   :on-value-change (fn [v idx]
                                      (let [style (keyword v)]
                                        (swap! local assoc-in [:map-style] style)))}
           (for [[k style] mapbox-style-url]
             ^{:key k}
             [picker-item {:label (name k) :value k}])]]]))))