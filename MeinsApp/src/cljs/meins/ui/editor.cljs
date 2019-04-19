(ns meins.ui.editor
  (:require [re-frame.core :refer [subscribe]]
            [meins.ui.shared :refer [view text text-input touchable-opacity btn
                                     keyboard-avoiding-view keyboard fa-icon alert]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [meins.ui.db :refer [emit]]
            [reagent.core :as r]
            [meins.ui.colors :as c]
            [meins.helpers :as h]
            [meins.utils.parse :as p]))

(def local (r/atom {:md ""}))

(defn header [save-fn cancel-fn label]
  (let [theme (subscribe [:active-theme])]
    (fn [save-fn cancel-fn]
      (let [button-bg (get-in c/colors [:button-bg @theme])
            btn-text (get-in c/colors [:btn-text @theme])
            header-color (get-in c/colors [:header-text @theme])]
        [view {:style {:display         "flex"
                       :flex-direction  "row"
                       :justify-content "space-between"
                       :height          45}}
         [touchable-opacity {:on-press cancel-fn
                             :style    {:width                      100
                                        :background-color           button-bg
                                        :border-top-right-radius    4
                                        :border-bottom-right-radius 4
                                        :padding                    8}}
          [text {:style {:font-size  20
                         :text-align "center"
                         :color      btn-text}}
           "cancel"]]
         [text {:style {:padding     8
                        :color       header-color
                        :font-weight :bold
                        :font-size   20}}
          label]
         [touchable-opacity {:on-press save-fn
                             :style    {:padding                   8
                                        :display                   :flex
                                        :background-color          button-bg
                                        :width                     100
                                        :border-top-left-radius    4
                                        :border-bottom-left-radius 4
                                        :align-items               :center}}
          [text {:style {:color      btn-text
                         :text-align "center"
                         :font-size  20}}
           "save"]]]))))

(defn editor [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} (js->clj navigation :keywordize-keys true)
            cancel-fn (fn []
                        (.dismiss keyboard)
                        (navigate "Journal"))
            save-fn #(let [new-entry (p/parse-entry (:md @local))]
                       (h/new-entry-fn emit new-entry)
                       (swap! local assoc-in [:md] "")
                       (.dismiss keyboard)
                       (navigate "Journal"))
            bg (get-in c/colors [:list-bg @theme])
            text-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])
            header-color (get-in c/colors [:header-text @theme])]
        ;(swap! local2 assoc :navigate navigate)
        [view {:style {:display        "flex"
                       :flex-direction "column"
                       :padding-top    50}}
         [header save-fn cancel-fn "New Entry"]
         [keyboard-avoiding-view {:behavior "padding"
                                  :style    {:display          "flex"
                                             :flex-direction   "column"
                                             :justify-content  "space-between"
                                             :background-color bg
                                             :flex             1
                                             :margin-top       20
                                             :align-items      "center"}}
          [text-input {:style              {:flex             2
                                            :font-weight      "100"
                                            :padding          16
                                            :font-size        24
                                            :max-height       400
                                            :min-height       300
                                            :background-color text-bg
                                            :margin-bottom    20
                                            :color            text-color
                                            :width            "100%"}
                       :multiline          true
                       ;:default-value      (:md @local)
                       :keyboard-type      "twitter"
                       :keyboardAppearance (if (= @theme :dark) "dark" "light")
                       :on-change-text     (fn [text]
                                             (swap! local assoc-in [:md] text))}]]]))))

#_(defn editor-tab [local put-fn theme]
    (let [local2 (r/atom {})
          #_#_save-fn #(let [new-entry (p/parse-entry (:md @local))]
                         (h/new-entry-fn put-fn new-entry)
                         (swap! local assoc-in [:md] "")
                         (when-let [navigate (:navigate @local2)]
                           (.dismiss keyboard)
                           (navigate "journal")))
          cancel-fn #(when-let [navigate (:navigate @local2)]
                       (.dismiss keyboard)
                       (navigate "journal"))
          header-bg (get-in c/colors [:header-tab @theme])
          text-color (get-in c/colors [:text @theme])
          header-right (fn [_]
                         [touchable-opacity {;:on-press save-fn
                                             :style {:padding-top    8
                                                     :padding-left   12
                                                     :padding-right  12
                                                     :padding-bottom 8}}
                          [text {:style {:color      "#0078e7"
                                         :text-align "center"
                                         :font-size  18}}
                           "save"]])
          header-left (fn [_]
                        [touchable-opacity {:on-press cancel-fn
                                            :style    {:padding-top    8
                                                       :padding-left   12
                                                       :padding-right  12
                                                       :padding-bottom 8}}
                         [text {:style {:color      "#0078e7"
                                        :text-align "center"
                                        :font-size  18}}
                          "cancel"]])
          opts {:title            "Add Entry"
                :headerRight      header-right
                :headerLeft       header-left
                :headerTitleStyle {:color text-color}
                :headerStyle      {:backgroundColor header-bg}}]
      (stack-navigator
        {:editor {:screen (stack-screen (editor local local2 put-fn) opts)}})))
