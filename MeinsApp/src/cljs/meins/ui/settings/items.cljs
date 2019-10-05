(ns meins.ui.settings.items
  (:require [meins.ui.shared :refer [fa-icon switch text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [reg-sub subscribe]]
            [reagent.core :as r]))

(defn item [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label info on-press has-nav-arrow]}]
      (let [header-color (get-in styles/colors [:header-text @theme])]
        [touchable-opacity {:on-press on-press
                            :style    {:color             header-color
                                       :margin-left       9
                                       :margin-right      15
                                       :height            58
                                       :display           :flex
                                       :borderBottomColor "#BBBDBF"
                                       :borderBottomWidth 0.5
                                       :flex-direction    :row
                                       :align-items       :center
                                       :justify-content   :space-between}}
         [text {:style {:font-size   12
                        :font-family "Montserrat-Regular"
                        :text-align  "center"
                        :opacity     0.68
                        :color       "white"}}
          label]
         (when info
           [text {:style {:font-size   12
                          :font-family "Montserrat-Medium"
                          :text-align  "center"
                          :color       "white"}}
            info])
         (when has-nav-arrow
           [fa-icon {:name  "angle-right"
                     :size  30
                     :style {:color       "#BBBDBF"
                             :margin-left 25}}])]))))

(defn switch-item [{:keys [initial-val]}]
  (let [theme (subscribe [:active-theme])
        local (r/atom {:on initial-val})]
    (fn [{:keys [label info on-toggle]}]
      (let [header-color (get-in styles/colors [:header-text @theme])
            toggle (fn [_]
                     (swap! local update :on not)
                     (on-toggle))]
        [touchable-opacity {:style {:color             header-color
                                    :margin-left       9
                                    :margin-right      15
                                    :height            58
                                    :display           :flex
                                    :borderBottomColor "#BBBDBF"
                                    :borderBottomWidth 0.5
                                    :flex-direction    :row
                                    :align-items       :center
                                    :justify-content   :space-between}}
         [text {:style {:font-size   12
                        :font-family "Montserrat-Regular"
                        :text-align  "center"
                        :opacity     0.68
                        :color       "white"}}
          label]
         [switch {:onValueChange toggle
                  :value         (:on @local)
                  :thumbColor    (if (:on @local)
                                   "#79C693"
                                   "#BBBDBF")
                  :trackColor    {:true  "#FFF"
                                  :false "#808080"}}
          info]]))))
