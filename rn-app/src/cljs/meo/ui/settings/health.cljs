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
  (let [weight-fn #(put-fn [:healthkit/weight])
        bp-fn #(put-fn [:healthkit/bp])
        theme (subscribe [:active-theme])
        steps-fn #(dotimes [n 7] (put-fn [:healthkit/steps n]))
        sleep-fn #(put-fn [:healthkit/sleep])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [import-item weight-fn "Weight" "balance-scale"]
         [import-item bp-fn "Blood Pressure" "heartbeat"]
         [import-item steps-fn "Steps" "forward"]
         [import-item sleep-fn "Sleep" "bed"]]))))
