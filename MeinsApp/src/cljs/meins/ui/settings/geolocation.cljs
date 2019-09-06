(ns meins.ui.settings.geolocation
  (:require [meins.ui.colors :as c]
            [meins.ui.shared :refer [view settings-list settings-list-item status-bar]]
            [re-frame.core :refer [subscribe]]
            [meins.ui.db :refer [emit]]))

(defn geo-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        toggle-geo (fn [_]
                     (if (:bg-geo @cfg)
                       (emit [:bg-geo/stop])
                       (emit [:bg-geo/start]))
                     (emit [:cfg/set {:bg-geo (not (:bg-geo @cfg))}]))]
    (fn [{:keys [_navigation] :as _props}]
      (let [bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:button-bg @theme])
            text-color (get-in c/colors [:btn-text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :width        "100%"}
          [settings-list-item {:title               "Enable Background Location Tracking"
                               :has-switch          true
                               :switchState         (:bg-geo @cfg)
                               :switchOnValueChange toggle-geo
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]]]))))
