(ns meins.ui.settings.items
  (:require [meins.ui.shared :refer [fa-icon status-bar switch text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [reg-sub subscribe]]
            [reagent.core :as r]))

(defn item [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label icon info on-press has-nav-arrow]}]
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
         icon
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

(defn button [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label on-press]}]
      (let [header-color (get-in styles/colors [:header-text @theme])
            nav-bg (get-in styles/colors [:nav-bg @theme])]
        [touchable-opacity {:on-press on-press
                            :style    {:color           header-color
                                       :margin-left     9
                                       :margin-right    15
                                       :height          80
                                       :margin-top      30
                                       :display         :flex
                                       :flex-direction  :row
                                       :align-items     :center
                                       :justify-content :space-between}}
         [view {:style {:background-color nav-bg
                        :display          :flex
                        :flex-direction   :row
                        :flex             1
                        :align-items      :center
                        :justify-content  :center
                        :padding-top      10
                        :padding-right    20
                        :padding-bottom   10
                        :padding-left     10
                        :border-radius    18}}
          [text {:style {:font-size   12
                         :font-family :Montserrat-SemiBold
                         :text-align  :center
                         :opacity     0.68
                         :color       "white"}}
           label]]]))))

(defn switch-item [{:keys []}]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label info on-toggle value]}]
      (let [header-color (get-in styles/colors [:header-text @theme])]
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
         [switch {:onValueChange on-toggle
                  :value         value
                  :thumbColor    (if value
                                   "#79C693"
                                   "#BBBDBF")
                  :trackColor    {:true  "#FFF"
                                  :false "#808080"}}
          info]]))))

(defn settings-page [& args]
  (let [theme (subscribe [:active-theme])]
    (fn [& args]
      (let [bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:display          :flex
                       :flex-direction   :column
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         (into [view {:style {:display       :flex
                              :padding-left  24
                              :padding-right 24}}]
               args)]))))

(defn settings-text [s]
  [text {:style {:font-size   12
                 :font-family :Montserrat-Regular
                 :text-align  :left
                 :opacity     0.68
                 :color       :white}}
   s])

(defn screen [{:keys [screen title]}]
  {:screen            (r/reactify-component screen)
   :navigationOptions {:title                title
                       :headerBackTitle      "BACK"
                       :headerBackTitleStyle {:fontSize      12
                                              :letterSpacing 0.02
                                              :fontFamily    "Montserrat-Regular"
                                              :color         "white"}
                       :headerTitleStyle     {:fontSize      18
                                              :lineHeight    22
                                              :letterSpacing 0.02
                                              :fontFamily    "Montserrat-SemiBold"
                                              :color         "white"}}})
