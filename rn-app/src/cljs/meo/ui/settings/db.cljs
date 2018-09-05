(ns meo.ui.settings.db
  (:require [meo.ui.shared :refer [view text settings-list settings-list-item]]
            [re-frame.core :refer [subscribe]]
            [meo.ui.settings.common :refer [settings-icon]]
            [meo.ui.colors :as c]))

(defn db-settings [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            reset-state #(do (put-fn [:state/reset]) (goBack))
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [settings-list {:border-color bg
                         :width        "100%"}
          [settings-list-item {:title            "Reset"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :icon             (settings-icon "bolt" "#999")
                               :on-press         reset-state}]]]))))
