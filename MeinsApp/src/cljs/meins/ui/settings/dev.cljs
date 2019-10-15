(ns meins.ui.settings.dev
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [item settings-page switch-item]]
            [meins.ui.shared :refer [status-bar view]]
            [re-frame.core :refer [subscribe]]))

(defn dev-settings [_props]
  (let [cfg (subscribe [:cfg])
        toggle-pvt #(emit [:cfg/set {:show-pvt (not (:show-pvt @cfg))}])
        toggle-debug #(emit [:cfg/set {:entry-pprint (not (:entry-pprint @cfg))}])]
    (fn [{:keys [navigation]}]
      [settings-page
       [switch-item {:label     "Show Private Entries"
                     :on-toggle toggle-pvt
                     :value     (:show-pvt @cfg)}]
       [switch-item {:label            "Debug Entry"
                     :on-toggle        toggle-debug
                     :btm-border-width 0
                     :value            (:entry-pprint @cfg)}]])))
