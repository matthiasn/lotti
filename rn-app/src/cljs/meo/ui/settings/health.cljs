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
                                       :padding          20
                                       :width            "100%"
                                       :background-color item-bg
                                       :justify-content  "flex-start"
                                       :align-items      "center"
                                       :height           60
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
        bp-fn     (fn [n] #(put-fn [:healthkit/bp {:n n}]))
        hrv-fn    (fn [n] #(put-fn [:healthkit/hrv {:n n}]))
        steps-fn  (fn [n] #(dotimes [i n] (put-fn [:healthkit/steps i])))
        sleep-fn  (fn [n] #(put-fn [:healthkit/sleep {:n n}]))
        theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [import-item (weight-fn 3) "Weight 3d" "balance-scale"]
         [import-item (weight-fn 365) "Weight 1y" "balance-scale"]
         [import-item (bp-fn 3) "Blood Pressure 3d" "heartbeat"]
         [import-item (bp-fn 365) "Blood Pressure 1y" "heartbeat"]
         [import-item (steps-fn 3) "Steps 3d" "forward"]
         [import-item (steps-fn 365) "Steps 1y" "forward"]
         [import-item (sleep-fn 3) "Sleep 3d" "bed"]
         [import-item (sleep-fn 365) "Sleep 1y" "bed"]
         [import-item (hrv-fn 7) "Heart Rate Variability" "heartbeat"]]))))
