(ns meins.ui.settings.db
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.icons.settings :as icns]
            [meins.ui.settings.items :refer [item settings-page switch-item]]
            [meins.ui.shared :refer [status-bar text view]]
            [re-frame.core :refer [subscribe]]))

(defn db-settings [{:keys [navigation]}]
  (let [{:keys [_navigate goBack]} (js->clj navigation :keywordize-keys true)
        reset-state #(do (emit [:state/reset]) (goBack))
        icon-size 26]
    [settings-page
     [item {:label            "RESET"
            :icon             (icns/db-icon icon-size)
            :btm-border-width 0
            :on-press         reset-state}]]))
