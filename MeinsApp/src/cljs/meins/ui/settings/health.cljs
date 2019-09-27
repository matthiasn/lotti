(ns meins.ui.settings.health
  (:require [meins.ui.styles :as styles]
            [meins.ui.shared :refer [view text fa-icon touchable-opacity status-bar]]
            [meins.ui.db :refer [emit]]
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
      (let [item-bg (get-in styles/colors [:button-bg @theme])
            text-color (get-in styles/colors [:btn-text @theme])]
        [view {:style {:margin-top       3
                       :width            "100%"
                       :background-color item-bg
                       :justify-content  "space-between"
                       :align-items      "center"
                       :flex-direction   "row"}}
         [touchable-opacity {:on-press click
                             :style    {:text-align       :left
                                        :display          :flex
                                        :flex-direction   :row
                                        :margin-top       3
                                        :padding          16
                                        :background-color item-bg
                                        :justify-content  "flex-start"
                                        :align-items      :center
                                        :height           50}}
          [view {:style {:width      44
                         :text-align :center}}
           [fa-icon {:name  icon-name
                     :size  20
                     :style {:color      text-color
                             :text-align :center}}]]
          [text {:style {:color       text-color
                         :font-size   14
                         :font-family "Montserrat-SemiBold"
                         :margin-left 20}}
           label]]
         [touchable-opacity {:on-press auto-check
                             :style    {:width       80
                                        :height      50
                                        :display     :flex
                                        :align-items :center}}
          [fa-icon {:name  "refresh"
                    :size  20
                    :style {:color      text-color
                            :text-align :center
                            :padding    16}}]]]))))

(defn health-settings [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation] :as _props}]
      (let [{:keys [_navigate _goBack]} navigation
            bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [import-item :healthkit/weight "Weight" "balance-scale"]
         [import-item :healthkit/bp "Blood Pressure" "heartbeat"]
         [import-item :healthkit/exercise "Exercise" "forward"]
         [import-item :healthkit/steps "Steps" "forward"]
         [import-item :healthkit/energy "Energy" "bolt"]
         [import-item :healthkit/sleep "Sleep" "bed"]
         [import-item :healthkit/hrv "Heart Rate Variability" "heartbeat"]]))))
