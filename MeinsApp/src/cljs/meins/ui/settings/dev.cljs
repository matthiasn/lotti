(ns meins.ui.settings.dev
  (:require [meins.ui.colors :as c]
            [meins.ui.shared :refer [view settings-list cam text settings-list-item status-bar]]
            [re-frame.core :refer [subscribe]]
            [cljs.tools.reader.edn :as edn]
            [meins.ui.db :refer [emit]]
            [reagent.core :as r]))

(defn dev-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        toggle-enable #(emit [:cfg/set {:entry-pprint (not (:entry-pprint @cfg))}])]
    (fn [{:keys [navigation] :as props}]
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
          [settings-list-item {:title               "Debug Entry"
                               :has-switch          true
                               :switchState         (:entry-pprint @cfg)
                               :switchOnValueChange toggle-enable
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]]]))))
