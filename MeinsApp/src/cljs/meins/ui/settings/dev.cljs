(ns meins.ui.settings.dev
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.shared :refer [settings-list settings-list-item status-bar view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn dev-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        toggle-pvt #(emit [:cfg/set {:show-pvt (not (:show-pvt @cfg))}])
        toggle-debug #(emit [:cfg/set {:entry-pprint (not (:entry-pprint @cfg))}])]
    (fn [{:keys [_navigation] :as _props}]
      (let [bg (get-in styles/colors [:list-bg @theme])
            item-bg (get-in styles/colors [:button-bg @theme])
            text-color (get-in styles/colors [:btn-text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :width        "100%"}
          [settings-list-item {:title               "Show Private Entries"
                               :has-switch          true
                               :switchState         (:show-pvt @cfg)
                               :switchOnValueChange toggle-pvt
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]
          [settings-list-item {:title               "Debug Entry"
                               :has-switch          true
                               :switchState         (:entry-pprint @cfg)
                               :switchOnValueChange toggle-debug
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]]]))))
