(ns meins.ui.settings.items
  (:require [meins.ui.icons.settings :as icns]
            [meins.ui.shared :refer [scroll status-bar switch text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [reg-sub subscribe]]
            [reagent.core :as r]))

(defn item [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label icon info on-press has-nav-arrow btm-border-width]}]
      (let [header-color (get-in styles/colors [:header-text @theme])
            btm-border-width (or btm-border-width 0.5)]
        [touchable-opacity {:on-press on-press
                            :style    {:color             header-color
                                       :margin-left       27
                                       :padding-right     17
                                       :height            58
                                       :display           :flex
                                       :borderBottomColor "#4A546E"
                                       :borderBottomWidth btm-border-width
                                       :flex-direction    :row
                                       :align-items       :center
                                       :justify-content   :space-between}}
         icon
         [text {:style {:font-size    12
                        :font-family  :Montserrat-Regular
                        :text-align   :left
                        :opacity      0.68
                        :flex         2
                        :padding-left 20
                        :color        :white}}
          label]
         (when info
           [text {:style {:font-size   12
                          :font-family "Montserrat-Medium"
                          :text-align  "center"
                          :color       "white"}}
            info])
         (when has-nav-arrow
           [icns/caret-icon 12])]))))

(defn button [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label on-press style]}]
      (let [header-color (get-in styles/colors [:header-text @theme])
            nav-bg (get-in styles/colors [:nav-bg @theme])]
        [touchable-opacity {:on-press on-press
                            :style    (merge {:color           header-color
                                              :margin-left     9
                                              :margin-right    15
                                              :height          80
                                              :margin-top      30
                                              :display         :flex
                                              :flex-direction  :row
                                              :justify-content :space-between
                                              :align-items     :center}
                                             style)}
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
    (fn [{:keys [label info on-toggle value btm-border-width]}]
      (let [header-color (get-in styles/colors [:header-text @theme])
            btm-border-width (or btm-border-width 0.5)]
        [touchable-opacity {:style {:color             header-color
                                    :margin-left       27
                                    :padding-right     17
                                    :height            58
                                    :display           :flex
                                    :borderBottomColor "#4A546E"
                                    :borderBottomWidth btm-border-width
                                    :flex-direction    :row
                                    :align-items       :center
                                    :justify-content   :space-between}}
         [text {:style {:font-size    12
                        :font-family  "Montserrat-Regular"
                        :text-align   "center"
                        :opacity      0.68
                        :padding-left 20
                        :color        "white"}}
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
        [scroll {:style {:display          :flex
                         :flex-direction   :column
                         :background-color bg
                         :padding-top      21
                         :padding-right    24
                         :padding-bottom   21
                         :padding-left     24
                         :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         (into [view {:style {:display          :flex
                              :background-color "rgba(74,84,110,0.29)"
                              :border-radius    18
                              :margin-top       10}}]
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
