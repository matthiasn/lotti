(ns meins.ui.settings.db
  (:require [meins.ui.settings.items :refer [item switch-item]]
            [meins.ui.shared :refer [status-bar text view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]))

(defn db-settings [_ put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation] :as _props} _put-fn]
      (let [{:keys [_navigate goBack]} (js->clj navigation :keywordize-keys true)
            bg (get-in styles/colors [:list-bg @theme])
            reset-state #(do (put-fn [:state/reset]) (goBack))]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [view {:style {:display       :flex
                        :padding-left  24
                        :padding-right 24}}
          [item {:label    "RESET"
                 :on-press reset-state}]]]))))
