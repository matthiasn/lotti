(ns meo.ui.tab-bar
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]))

(def ReactNative (js/require "react-native"))
(def vibration (.-Vibration ReactNative))
(def text (r/adapt-react-class (.-Text ReactNative)))
(def tab-bar (r/adapt-react-class (.-TabBarIOS ReactNative)))
(def react-native-vector-icons (js/require "react-native-vector-icons/FontAwesome"))
(def icon (r/adapt-react-class (aget react-native-vector-icons "default")))
(def tab-bar-item (r/adapt-react-class (aget react-native-vector-icons "TabBarItemIOS")))

(defn custom-tab-bar-item [{:keys [title icon selected badge on-press]}]
  [tab-bar-item {:title     title
                 :iconName  icon
                 :selected  selected
                 :padding   20
                 :on-press  on-press
                 :badge     badge
                 :iconSize  20
                 :iconColor "#987"}
   [text {:style {:font-size     6
                  :color         :white
                  :font-weight   "100"
                  :margin-bottom 5
                  :text-align    "center"}}
    title]])

(defn meo-tab-bar [local put-fn]
  (let [click-fn (fn [k]
                   (fn [_]
                     (.vibrate vibration 2000)
                     (swap! local assoc-in [:active-tab] k)))]
    [tab-bar {:style {:bar-tint-color "black"
                      :height         60
                      :flex           1
                      :padding-top    20
                      :bar-style      "black"
                      :width          "100%"}}
     [custom-tab-bar-item {:title    "Write"
                           :icon     "pencil"
                           :on-press (click-fn :main)
                           :selected (= (:active-tab @local) :main)}]
     [custom-tab-bar-item {:title    "Journal"
                           :icon     "list"
                           :on-press (click-fn :list)
                           :selected (= (:active-tab @local) :list)}]
     [custom-tab-bar-item {:title    "Health"
                           :icon     "heartbeat"
                           :on-press (click-fn :health)
                           :selected (= (:active-tab @local) :health)
                           :badge    5}]
     [custom-tab-bar-item {:title    "Film"
                           :icon     "film"
                           :on-press (click-fn :film)
                           :selected (= (:active-tab @local) :film)}]
     [custom-tab-bar-item {:title    "Settings"
                           :icon     "cogs"
                           :on-press (click-fn :settings)
                           :selected (= (:active-tab @local) :settings)}]]))
