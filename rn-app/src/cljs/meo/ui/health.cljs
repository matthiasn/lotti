(ns meo.ui.health
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight]]
            [re-frame.core :refer [reg-sub subscribe]]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn health-page [local put-fn]
  [view {:style {:flex-direction "column"
                 :padding-top    10
                 :padding-bottom 10
                 :padding-left   10
                 :padding-right  10}}

   [view {:style {:flex-direction "row"
                  :padding-top    10
                  :padding-bottom 10
                  :padding-left   10
                  :padding-right  10}}
    [touchable-highlight
     {:style    defaults
      :on-press #(put-fn [:healthkit/weight])}
     [text {:style {:color       "white"
                    :text-align  "center"
                    :font-weight "bold"}}
      "weight"]]
    [touchable-highlight
     {:style    defaults
      :on-press #(put-fn [:healthkit/bp])}
     [text {:style {:color       "white"
                    :text-align  "center"
                    :font-weight "bold"}}
      "bp"]]
    [touchable-highlight
     {:style    defaults
      :on-press #(dotimes [n 2]
                   (put-fn [:healthkit/steps n]))}
     [text {:style {:color       "white"
                    :text-align  "center"
                    :font-weight "bold"}}
      "steps"]]
    [touchable-highlight
     {:style    defaults
      :on-press #(put-fn [:healthkit/sleep])}
     [text {:style {:color       "white"
                    :text-align  "center"
                    :font-weight "bold"}}
      "sleep"]]]])