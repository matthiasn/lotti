(ns meo.ui.settings.health
  (:require [meo.ui.colors :as c]
            [meo.ui.shared :refer [view settings-list cam text settings-list-item icon]]
            [meo.ui.settings.common :as sc :refer [settings-icon]]
            [re-frame.core :refer [subscribe]]
            [cljs.tools.reader.edn :as edn]))

(defn health-settings [local put-fn]
  (let [weight-fn #(put-fn [:healthkit/weight])
        bp-fn #(put-fn [:healthkit/bp])
        theme (subscribe [:active-theme])
        steps-fn #(dotimes [n 7] (put-fn [:healthkit/steps n]))
        sleep-fn #(put-fn [:healthkit/sleep])
        current-activity (subscribe [:current-activity])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [settings-list {:border-color bg
                         :width        "100%"
                         :flex         1}
          [settings-list-item {:title            "Weight"
                               :hasNavArrow      false
                               :icon             (settings-icon "balance-scale" text-color)
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         weight-fn}]
          [settings-list-item {:title            "Blood Pressure"
                               :hasNavArrow      false
                               :background-color item-bg
                               :icon             (settings-icon "heartbeat" text-color)
                               :titleStyle       {:color text-color}
                               :on-press         bp-fn}]
          [settings-list-item {:title            "Steps"
                               :hasNavArrow      false
                               :background-color item-bg
                               :icon             (settings-icon "forward" text-color)
                               :titleStyle       {:color text-color}
                               :on-press         steps-fn}]
          [settings-list-item {:title            "Sleep"
                               :hasNavArrow      false
                               :icon             (settings-icon "bed" text-color)
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         sleep-fn}]]
         [text {:style {:margin-top    5
                        :margin-left   10
                        :margin-bottom 40
                        :color         "green"
                        :text-align    "left"
                        :font-size     30}}
          (-> @current-activity
              :sorted
              first
              :type)]]))))
