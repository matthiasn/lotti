(ns meo.ui.editor
  (:require [re-frame.core :refer [subscribe]]
            [meo.ui.shared :refer [view text text-input touchable-highlight btn
                                   keyboard-avoiding-view icon]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [meo.helpers :as h]
            [meo.utils.parse :as p]
            [reagent.core :as r]))

(defn editor [local local2 put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      (swap! local2 assoc :navigate navigate)
      [keyboard-avoiding-view {:behavior "padding"
                               :style    {:display          "flex"
                                          :flex-direction   "column"
                                          :justify-content  "space-between"
                                          :background-color "#F8F8F8"
                                          :flex             1
                                          :align-items      "center"}}
       [text-input {:style          {:flex             2
                                     :font-weight      "100"
                                     :padding          16
                                     :font-size        24
                                     :background-color "#FFF"
                                     :margin-bottom    20
                                     :width            "100%"}
                    :multiline      true
                    :default-value  (:md @local)
                    :keyboard-type  "twitter"
                    :on-change-text (fn [text]
                                      (swap! local assoc-in [:md] text))}]])))

(defn editor-tab [local put-fn]
  (let [local2 (r/atom {})
        save-fn #(let [new-entry (p/parse-entry (:md @local))
                       new-entry-fn (h/new-entry-fn put-fn new-entry nil)]
                   (new-entry-fn)
                   (swap! local assoc-in [:md] "")
                   (when-let [navigate (:navigate @local2)]
                     (navigate "journal")))]
    (stack-navigator
      {:editor {:screen (stack-screen
                          (editor local local2 put-fn)
                          {:title       "Add Entry"
                           :headerRight (fn [_]
                                          [touchable-highlight {:on-press save-fn
                                                                :style    {:padding 10}}
                                           [text {:style {:color      "#0078e7"
                                                          :text-align "center"
                                                          :font-size  20}}
                                            "save"]])})}})))
