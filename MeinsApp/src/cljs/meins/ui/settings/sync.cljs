(ns meins.ui.settings.sync
  (:require [meins.ui.colors :as c]
            [meins.ui.shared :refer [view settings-list cam text settings-list-item status-bar]]
            [re-frame.core :refer [subscribe]]
            [cljs.tools.reader.edn :as edn]
            [meins.ui.db :refer [emit]]
            [reagent.core :as r]))

(defn sync-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        local (r/atom {})
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (edn/read-string (get qr-code "data"))]
                            (swap! local assoc-in [:barcode] data)
                            (emit [:secrets/set data])
                            (swap! local assoc-in [:cam] false)))
        toggle-enable #(emit [:cfg/set {:sync-active (not (:sync-active @cfg))}])]
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
          [settings-list-item {:title               "Enable Sync"
                               :has-switch          true
                               :switchState         (:sync-active @cfg)
                               :switchOnValueChange toggle-enable
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]
          [settings-list-item {:title            "Scan barcode"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         #(swap! local update-in [:cam] not)}]]
         (when (:cam @local)
           [cam {:style         {:width  "100%"
                                 :flex   5
                                 :height "100%"}
                 :onBarCodeRead on-barcode-read}])
         (when-let [barcode (:barcode @local)]
           [text {:style {:font-size   10
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      5
                          :text-align  "center"}}
            (str barcode)])]))))