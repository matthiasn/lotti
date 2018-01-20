(ns meo.ui.editor
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.helpers :as h]
            [meo.utils.parse :as p]))

(def ReactNative (js/require "react-native"))
(def text (r/adapt-react-class (.-Text ReactNative)))
(def view (r/adapt-react-class (.-View ReactNative)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight ReactNative)))
(def text-input (r/adapt-react-class (.-TextInput ReactNative)))
(def react-native-vector-icons (js/require "react-native-vector-icons/FontAwesome"))
(def btn (r/adapt-react-class (aget react-native-vector-icons "default" "Button")))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn editor [local put-fn]
  (when (= (:active-tab @local) :main)
    [view {:style {:flex 2}}
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
                                    (swap! local assoc-in [:md] text))}]
     [view {:style {:padding-top    0
                    :padding-right  15
                    :padding-left   15
                    :padding-bottom 0
                    :width          120
                    :flex-grow      0
                    :height         150
                    :max-height     150}}
      [btn {:name     "floppy-o"
            :style    {:background-color "green"}
            :on-press #(let [new-entry (p/parse-entry (:md @local))
                             new-entry-fn (h/new-entry-fn put-fn new-entry nil)]
                         (new-entry-fn)
                         (swap! local assoc-in [:md] ""))}
       [text {:style {:color       :white
                      :text-align  "center"
                      :font-size   12
                      :font-weight "bold"}}
        "save"]]]]))
