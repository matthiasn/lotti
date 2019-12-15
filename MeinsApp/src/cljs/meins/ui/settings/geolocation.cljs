(ns meins.ui.settings.geolocation
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [item settings-page switch-item]]
            [re-frame.core :refer [subscribe]]))

(defn geo-settings [_]
  (let [cfg (subscribe [:cfg])
        toggle-geo (fn [_]
                     (if (:bg-geo @cfg)
                       (emit [:bg-geo/stop])
                       (emit [:bg-geo/start]))
                     (emit [:cfg/set {:bg-geo (not (:bg-geo @cfg))}]))]
    (fn [{:keys [_navigation] :as _props}]
      [settings-page
       [switch-item {:label     "Background Location Tracking"
                     :on-toggle toggle-geo
                     :value     (:bg-geo @cfg)}]
       [item {:label         "Sync"
              :has-nav-arrow false
              :on-press      #(emit [:bg-geo/save])}]
       [item {:label            "Email Log Files"
              :has-nav-arrow    false
              :btm-border-width 0
              :on-press         #(emit [:bg-geo/email-logs])}]])))
