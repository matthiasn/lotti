(ns meins.ui.settings.health
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.shared :refer [fa-icon status-bar text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn start-watching [])

(defn import-item [msg-type _label _icon-name]
  (let [theme (subscribe [:active-theme])
        n 30
        click (fn [_] (emit [msg-type {:n n}]))
        auto-check (fn [_]
                     (emit [:schedule/new
                            {:timeout (* 15 60 1000)
                             :message [msg-type {:n n}]
                             :id      msg-type
                             :repeat  true
                             :initial true}]))]
    (fn [_msg-type label icon-name]
      (let [text-color (get-in styles/colors [:btn-text @theme])]
        [view {:style {:width             "100%"
                       :justify-content   "space-between"
                       :borderBottomColor "#BBBDBF"
                       :borderBottomWidth 0.5
                       :align-items       :center
                       :display           :flex
                       :opacity           0.68
                       :height            58
                       :flex-direction    "row"}}
         [touchable-opacity {:on-press click
                             :style    {:text-align      :left
                                        :flex-direction  :row
                                        :padding-top     20
                                        :height          "100%"
                                        :width           250
                                        :justify-content "flex-start"}}
          [view {:style {:width      44
                         :text-align :center}}
           [fa-icon {:name  icon-name
                     :size  20
                     :style {:color      text-color
                             :text-align :center}}]]
          [text {:style {:color       text-color
                         :font-size   14
                         :font-family "Montserrat-Regular"
                         :margin-left 20}}
           label]]
         [touchable-opacity {:on-press auto-check
                             :style    {:width       80
                                        :height      "100%"
                                        :padding-top 20
                                        :display     :flex
                                        :align-items :center}}
          [fa-icon {:name  "refresh"
                    :size  20
                    :style {:color      text-color
                            :text-align :center}}]]]))))

(defn health-settings [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation] :as _props}]
      (let [{:keys [_navigate _goBack]} navigation
            bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [view {:style {:display       :flex
                        :padding-left  24
                        :padding-right 24}}
          [import-item :healthkit/weight "Weight" "balance-scale"]
          [import-item :healthkit/bp "Blood Pressure" "heartbeat"]
          [import-item :healthkit/exercise "Exercise" "forward"]
          [import-item :healthkit/steps "Steps" "forward"]
          [import-item :healthkit/energy "Energy" "bolt"]
          [import-item :healthkit/sleep "Sleep" "bed"]
          [import-item :healthkit/hrv "Heart Rate Variability" "heartbeat"]]]))))
