(ns meins.ui.settings.geolocation
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [item switch-item]]
            [meins.ui.shared :refer [settings-icon settings-list settings-list-item status-bar view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn geo-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        toggle-geo (fn [_]
                     (if (:bg-geo @cfg)
                       (emit [:bg-geo/stop])
                       (emit [:bg-geo/start]))
                     (emit [:cfg/set {:bg-geo (not (:bg-geo @cfg))}]))]
    (fn [{:keys [_navigation] :as _props}]
      (let [bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [view {:style {:display       :flex
                        :padding-left  24
                        :padding-right 24}}
          [switch-item {:label     "Background Location Tracking"
                        :on-toggle toggle-geo
                        :value     (:bg-geo @cfg)}]
          [item {:label         "SYNC"
                 :has-nav-arrow false
                 :on-press      #(emit [:bg-geo/save])}]
          [item {:label         "EMAIL LOG FILES"
                 :has-nav-arrow false
                 :on-press      #(emit [:bg-geo/email-logs])}]]]))))
