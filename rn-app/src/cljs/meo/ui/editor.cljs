(ns meo.ui.editor
  (:require [re-frame.core :refer [subscribe]]
            [meo.ui.shared :refer [view text text-input touchable-opacity btn
                                   keyboard-avoiding-view icon]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [meo.helpers :as h]
            [meo.utils.parse :as p]
            [reagent.core :as r]
            [meo.ui.colors :as c]))

(defn editor [local local2 put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        (swap! local2 assoc :navigate navigate)
        [keyboard-avoiding-view {:behavior "padding"
                                 :style    {:display          "flex"
                                            :flex-direction   "column"
                                            :justify-content  "space-between"
                                            :background-color bg
                                            :flex             1
                                            :align-items      "center"}}
         [text-input {:style              {:flex             2
                                           :font-weight      "100"
                                           :padding          16
                                           :font-size        24
                                           :max-height       400
                                           :background-color text-bg
                                           :margin-bottom    20
                                           :color            text-color
                                           :width            "100%"}
                      :multiline          true
                      :default-value      (:md @local)
                      :keyboard-type      "twitter"
                      :keyboardAppearance (if (= @theme :dark) "dark" "light")
                      :on-change-text     (fn [text]
                                            (swap! local assoc-in [:md] text))}]]))))

(defn editor-tab [local put-fn theme]
  (let [local2 (r/atom {})
        save-fn #(let [new-entry (p/parse-entry (:md @local))]
                   (h/new-entry-fn put-fn new-entry)
                   (swap! local assoc-in [:md] "")
                   (when-let [navigate (:navigate @local2)]
                     (navigate "journal")))
        header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        header-right (fn [_]
                       [touchable-opacity {:on-press save-fn
                                           :style    {:padding-top    8
                                                      :padding-left   12
                                                      :padding-right  12
                                                      :padding-bottom 8}}
                        [text {:style {:color      "#0078e7"
                                       :text-align "center"
                                       :font-size  18}}
                         "save"]])
        opts {:title            "Add Entry"
              :headerRight      header-right
              :headerTitleStyle {:color text-color}
              :headerStyle      {:backgroundColor header-bg}}]
    (stack-navigator
      {:editor {:screen (stack-screen (editor local local2 put-fn) opts)}})))
