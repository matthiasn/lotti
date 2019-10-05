(ns meins.ui.settings.dev
  (:require [meins.ui.db :refer [emit]]
            [meins.ui.settings.items :refer [item switch-item]]
            [meins.ui.shared :refer [status-bar view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn dev-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        toggle-pvt #(emit [:cfg/set {:show-pvt (not (:show-pvt @cfg))}])
        toggle-debug #(emit [:cfg/set {:entry-pprint (not (:entry-pprint @cfg))}])]
    (fn [{:keys [_navigation] :as _props}]
      (let [bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [view {:style {:display       :flex
                        :padding-left  24
                        :padding-right 24}}
          [switch-item {:label       "Show Private Entries"
                        :on-toggle   toggle-pvt
                        :initial-val (:show-pvt @cfg)}]
          [switch-item {:label       "Debug Entry"
                        :on-toggle   toggle-debug
                        :initial-val (:entry-pprint @cfg)}]]]))))
