(ns meins.ui.settings.geolocation
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [item switch-item settings-page]]
            [meins.ui.shared :refer [status-bar view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn geo-settings [_]
  (let [cfg (subscribe [:cfg])
        toggle-geo (fn [_]
                     (if (:bg-geo @cfg)
                       (emit [:bg-geo/stop])
                       (emit [:bg-geo/start]))
                     (emit [:cfg/set {:bg-geo (not (:bg-geo @cfg))}]))]
    (fn [{:keys [_navigation] :as _props}]
      (let []
        [settings-page
         [switch-item {:label     "Background Location Tracking"
                       :on-toggle toggle-geo
                       :value     (:bg-geo @cfg)}]
         [item {:label         "SYNC"
                :has-nav-arrow false
                :on-press      #(emit [:bg-geo/save])}]
         [item {:label         "EMAIL LOG FILES"
                :has-nav-arrow false
                :on-press      #(emit [:bg-geo/email-logs])}]]))))
