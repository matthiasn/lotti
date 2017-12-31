(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [cljs.pprint :as pp]
            [meo.helpers :as h]
            [meo.utils.parse :as p]))

(defonce put-fn-atom (r/atom nil))

(def ReactNative (js/require "react-native"))
(def react-native-camera (js/require "react-native-camera"))
(def cam (r/adapt-react-class (aget react-native-camera "default")))

(def app-registry (.-AppRegistry ReactNative))
(def text (r/adapt-react-class (.-Text ReactNative)))
(def tab-bar (r/adapt-react-class (.-TabBarIOS ReactNative)))
(def tab-bar-item (r/adapt-react-class (.-Item (.-TabBarIOS ReactNative))))
(def view (r/adapt-react-class (.-View ReactNative)))
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView ReactNative)))
(def image (r/adapt-react-class (.-Image ReactNative)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight ReactNative)))
(def logo-img (js/require "./images/cljs.png"))
(def text-input (r/adapt-react-class (.-TextInput ReactNative)))

(.log js/console cam)

(defn alert [title]
  (.alert (.-Alert ReactNative) title))

(reg-sub :entries (fn [db _] (:entries db)))

(defn menu-bar [local]
  (let [defaults {:background-color "blue"
                  :padding-left     15
                  :padding-right    15
                  :padding-top      10
                  :padding-bottom   10
                  :margin-right     10}]
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
       {:style    (merge defaults {:background-color "green"})
        :on-press #(let [put-fn @put-fn-atom
                         new-entry (p/parse-entry (:md @local))
                         new-entry-fn (h/new-entry-fn put-fn new-entry nil)]
                     (new-entry-fn)
                     (swap! local assoc-in [:md] ""))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "save"]]
      [touchable-highlight
       {:style    defaults
        :on-press #(swap! local update-in [:cam] not)}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        (if (:cam @local) "hide cam" "ws")]]
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (put-fn [:sync/initiate]))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "sync"]]
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (put-fn [:sync/reset]))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "reset"]]]
     [view {:style {:flex-direction "row"
                    :padding-top    10
                    :padding-bottom 10
                    :padding-left   10
                    :padding-right  10}}
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (put-fn [:healthkit/weight]))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "weight"]]
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (put-fn [:healthkit/bp]))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "bp"]]
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (dotimes [n 100]
                       (put-fn [:healthkit/steps n])))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "steps"]]
      [touchable-highlight
       {:style    defaults
        :on-press #(let [put-fn @put-fn-atom]
                     (put-fn [:healthkit/sleep]))}
       [text {:style {:color       "white"
                      :text-align  "center"
                      :font-weight "bold"}}
        "sleep"]]]]))

(defn app-root [put-fn]
  (let [entries (subscribe [:entries])
        local (r/atom {:cam false
                       :md  "hello world"})
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (get qr-code "data")]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host data}])
                            (swap! local assoc-in [:cam] false)))]
    (fn []
      [keyboard-avoiding-view
       {:keyboardVerticalOffset 0
        :style                  {:flex-direction   "column"
                                 :padding-top      30
                                 :padding-bottom   30
                                 :padding-left     20
                                 :padding-right    20
                                 :height           "100%"
                                 :background-color "#777"
                                 :align-items      "center"}}
       [text {:style {:font-size     10
                      :color         :white
                      :font-weight   "100"
                      :margin-bottom 5
                      :text-align    "center"}}
        (str (count @entries) " entries")]

       [menu-bar local]

       (when-let [barcode (:barcode @local)]
         [text {:style {:font-size     10
                        :color         :white
                        :font-weight   "100"
                        :margin-bottom 5
                        :text-align    "center"}}
          (str barcode)])

       #_[image {:source logo-img
                 :style  {:width         80
                          :height        80
                          :margin-bottom 5}}]

       #_[tab-bar {:style {:tintColor        :black
                           :height           5
                           :background-color "#BBB"}}
          [tab-bar-item {:title    "Steps"
                         :selected true
                         :icon     logo-img}
           [text {:style {:font-size     10
                          :color         :white
                          :font-weight   "100"
                          :margin-bottom 5
                          :text-align    "center"}}
            "Steps"]]
          [tab-bar-item {:title "BP"
                         :icon  logo-img}
           [text {:style {:font-size     10
                          :color         :white
                          :font-weight   "100"
                          :margin-bottom 5
                          :text-align    "center"}}
            "BP"]]]

       [view {:style {:flex  2
                      :width "100%"}}
        (if (:cam @local)
          [cam {:style         {:width  "100%"
                                :height 300}
                :onBarCodeRead on-barcode-read}]
          [text-input {:style          {:flex             1
                                        :font-weight      "100"
                                        :padding          10
                                        :font-size        20
                                        :background-color "#CCC"
                                        :width            "100%"}
                       :multiline      true
                       :default-value  (:md @local)
                       :keyboard-type  "twitter"
                       :on-change-text (fn [text]
                                         (swap! local assoc-in [:md] text))}])]

       #_[text {:style {:font-size     10
                        :font-weight   "500"
                        :color         "#CCC"
                        :margin-bottom 20
                        :text-align    "center"}}
          (with-out-str (pp/pprint (second (last (sort-by first @entries)))))]
       #_[image {:source logo-img
                 :style  {:width         80
                          :height        80
                          :margin-bottom 5}}]
       ])))

(defn state-fn [put-fn]
  (let [app-root (app-root put-fn)
        register #(r/reactify-component app-root)]
    (.registerComponent app-registry "meo" register)
    (reset! put-fn-atom put-fn))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
