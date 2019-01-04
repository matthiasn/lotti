(ns meo.ui.settings.health
  (:require [meo.ui.colors :as c]
            [meo.ui.shared :refer [view settings-list cam text settings-list-item icon
                                   touchable-opacity]]
            [meo.ui.settings.common :as sc :refer [settings-icon]]
            [re-frame.core :refer [subscribe]]
            [cljs.tools.reader.edn :as edn]))

(defn import-item [click label icon-name]
  (let [theme (subscribe [:active-theme])]
    (fn [click label icon-name]
      (let [item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [touchable-opacity {:on-press click
                            :style    {:margin-top       3
                                       :padding          16
                                       :width            "100%"
                                       :background-color item-bg
                                       :justify-content  "flex-start"
                                       :align-items      "center"
                                       :height           50
                                       :flex-direction   "row"}}
         [view {:style {:width      44
                        :text-align :center}}
          [icon {:name  icon-name
                 :size  20
                 :style {:color      text-color
                         :text-align :center}}]]
         [text {:style {:color       text-color
                        :font-size   20
                        :margin-left 20}}
          label]]))))

(defn health-settings [local put-fn]
  (let [weight-fn (fn [n] #(put-fn [:healthkit/weight {:n n}]))
        bp-fn (fn [n] #(put-fn [:healthkit/bp {:n n}]))
        hrv-fn (fn [n] #(put-fn [:healthkit/hrv {:n n}]))
        steps-fn (fn [n] #(put-fn [:healthkit/steps {:n n}]))
        energy-fn (fn [n] #(put-fn [:healthkit/energy {:n n}]))
        sleep-fn (fn [n] #(put-fn [:healthkit/sleep {:n n}]))
        exercise-fn (fn [n] #(put-fn [:healthkit/exercise {:n n}]))
        theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [import-item (weight-fn 30) "Weight" "balance-scale"]
         [import-item (bp-fn 30) "Blood Pressure" "heartbeat"]
         [import-item (exercise-fn 30) "Exercise" "forward"]
         [import-item (steps-fn 30) "Steps" "forward"]
         [import-item (energy-fn 30) "Energy" "bolt"]
         [import-item (sleep-fn 30) "Sleep" "bed"]
         [import-item (hrv-fn 30) "Heart Rate Variability" "heartbeat"]]))))
