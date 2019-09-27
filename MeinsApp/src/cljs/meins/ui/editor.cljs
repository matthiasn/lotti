(ns meins.ui.editor
  (:require [re-frame.core :refer [subscribe]]
            [meins.ui.shared :refer [view text text-input touchable-opacity platform-os status-bar
                                     keyboard-avoiding-view keyboard scroll]]
            [meins.ui.db :refer [emit]]
            [reagent.core :as r]
            [meins.ui.styles :as styles]
            [meins.helpers :as h]
            [meins.common.utils.parse :as p]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.string :as s]))

(def local (r/atom {:md ""}))

(defn header [_save-fn _cancel-fn _label]
  (let [theme (subscribe [:active-theme])]
    (fn [save-fn cancel-fn label]
      (let [button-bg (get-in styles/colors [:button-bg @theme])
            btn-text (get-in styles/colors [:btn-text @theme])
            header-color (get-in styles/colors [:header-text @theme])]
        [view {:style {:display         "flex"
                       :flex-direction  "row"
                       :justify-content "space-between"
                       :height          45}}
         [touchable-opacity {:on-press cancel-fn
                             :style    {:width         100
                                        :margin-left   10
                                        :border-radius 18
                                        :padding       8}}
          [text {:style {:font-size  20
                         :text-align "left"
                         :color      btn-text}}
           "X"]]
         [text {:style {:padding     8
                        :color       header-color
                        :font-family "Montserrat-SemiBold"
                        :font-weight :bold
                        :font-size   18}}
          label]
         [touchable-opacity {:on-press save-fn
                             :style    {:display          :flex
                                        :background-color button-bg
                                        :width            81
                                        :margin-right     17
                                        :border-radius    18
                                        :height           36
                                        :align-items      :center}}
          [text {:style {:color       btn-text
                         :text-align  "center"
                         :line-height 21
                         :font-family "Montserrat-Regular"
                         :padding-top 7
                         :font-size   15}}
           "SAVE"]]]))))

(defn editor [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation] :as _props}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            cancel-fn (fn []
                        (.dismiss keyboard)
                        (navigate "Journal"))
            save-fn #(let [new-entry (h/parse-entry (:md @local))]
                       (h/new-entry-fn emit new-entry)
                       (swap! local assoc-in [:md] "")
                       (.dismiss keyboard)
                       (js/setTimeout (fn [_] (navigate "Journal")) 500))
            bg (get-in styles/colors [:list-bg @theme])
            text-bg (get-in styles/colors [:text-bg @theme])
            text-color (get-in styles/colors [:text @theme])
            pt (if (= platform-os "ios") 40 10)]
        [view {:style {:display          "flex"
                       :flex-direction   "column"
                       :height           "100%"
                       :background-color bg
                       :padding-top      pt}}
         [status-bar {:barStyle "light-content"}]
         [header save-fn cancel-fn "New Entry"]
         [view {:display         :flex
                :flex-direction  :row
                :justify-content :center
                :padding-top     7
                :opacity         0.68}
          [text {:style {:color       text-color
                         :text-align  "center"
                         :font-weight :bold
                         :font-family "Montserrat-SemiBold"
                         :font-size   12}}
           (s/upper-case
             (h/entry-date-fmt (stc/now)))]
          [text {:style {:color       text-color
                         :text-align  "center"
                         :margin-left 12
                         :font-family "Montserrat-Regular"
                         :font-size   12}}
           (h/hh-mm (stc/now))]]
         [keyboard-avoiding-view {;:behavior "padding"
                                  :style {:display         "flex"
                                          :flex-direction  "column"
                                          :justify-content "space-between"
                                          :flex            2
                                          :margin-top      10
                                          :height          500
                                          :align-items     "center"}}
          [scroll {:style {:flex-direction "column"
                           :display        "flex"
                           :width          "100%"
                           :flex           1
                           :padding-left   18
                           :padding-right  16
                           :padding-bottom 10}}
           [text-input {:style              {:flex             2
                                             :font-weight      "100"
                                             :padding          16
                                             :font-size        24
                                             :max-height       400
                                             :min-height       240
                                             :border-radius    18
                                             :font-family      "Montserrat-Regular"
                                             :background-color text-bg
                                             :margin-bottom    20
                                             :color            text-color
                                             :width            "auto"}
                        :multiline          true
                        :default-value      (:md @local)
                        :keyboard-type      "twitter"
                        :keyboardAppearance (if (= @theme :dark) "dark" "light")
                        :on-change-text     (fn [text]
                                              (swap! local assoc-in [:md] text))}]]]]))))
