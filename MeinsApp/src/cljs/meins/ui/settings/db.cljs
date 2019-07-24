(ns meins.ui.settings.db
  (:require [meins.ui.shared :refer [view text settings-list settings-list-item alert status-bar]]
            [re-frame.core :refer [subscribe]]
    ;[mein.ui.settings.common :refer [settings-icon]]
    ;       [meo.ui.colors :as c]
            ))

(defn db-settings [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      ;(alert (js->clj navigation :keywordize-keys true))
      (let [{:keys [navigate goBack]} (js->clj navigation :keywordize-keys true)
            reset-state #(do (put-fn [:state/reset]) (goBack))
            bg "#445"                                       ;(get-in c/colors [:list-bg @theme])
            item-bg "#556"                                  ;(get-in c/colors [:text-bg @theme])
            text-color "white"                              ;(get-in c/colors [:text @theme])
            ]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :width        "100%"}
          #_
          [settings-list-item {:title            "Back"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               ; :icon             (settings-icon "bolt" "#999")
                               ;:on-press         #(navigate "settings")
                               :on-press         #(alert "foo")}]
          [settings-list-item {:title            "Reset"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               ; :icon             (settings-icon "bolt" "#999")
                               :on-press         reset-state}]]]))))
