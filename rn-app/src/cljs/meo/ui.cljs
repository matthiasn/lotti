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
(def view (r/adapt-react-class (.-View ReactNative)))
(def image (r/adapt-react-class (.-Image ReactNative)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight ReactNative)))
;(def logo-img (js/require "./images/icon.png"))
(def text-input (r/adapt-react-class (.-TextInput ReactNative)))

(.log js/console cam)

(defn alert [title]
  (.alert (.-Alert ReactNative) title))

(reg-sub :entries (fn [db _] (:entries db)))

(defn app-root [put-fn]
  (let [entries (subscribe [:entries])
        local (r/atom {:cam false
                       :md "hello world"})
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (get qr-code "data")]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host data}])
                            (swap! local assoc-in [:cam] false)))]
    (fn []
      [view {:style {:flex-direction   "column"
                     :padding-top      30
                     :padding-bottom   30
                     :padding-left     20
                     :padding-right    20
                     :height           "100%"
                     :background-color "#222"
                     :align-items      "center"}}
       [text {:style {:font-size     10
                      :color         :white
                      :font-weight   "100"
                      :margin-bottom 5
                      :text-align    "center"}}
        (str (count @entries) " entries")]

       [touchable-highlight
        {:style    {:background-color "blue"
                    :padding-left     20
                    :padding-right    20
                    :padding-top      12
                    :padding-bottom   12
                    :margin-right     20}
         :on-press #(swap! local update-in [:cam] not)}
        [text {:style {:color       "white"
                       :text-align  "center"
                       :font-weight "bold"}}
         (if (:cam @local) "hide cam" "show cam")]]

       (when-let [barcode (:barcode @local)]
         [text {:style {:font-size     10
                        :color         :white
                        :font-weight   "100"
                        :margin-bottom 5
                        :text-align    "center"}}
          (str barcode)])

       (if (:cam @local)
         [cam {:style {:width  300
                       :height 300}
               :onBarCodeRead on-barcode-read}
          [text {:style {:font-size     20
                         :color         :white
                         :font-weight   "300"
                         :margin-bottom 5
                         :text-align    "center"}}
           "take"]]
         [text-input {:style          {:height           200
                                       :font-weight      "100"
                                       :padding          10
                                       :font-size        20
                                       :background-color "#CCC"
                                       :width            "100%"}
                      :multiline      true
                      :default-value  (:md @local)
                      :keyboard-type  "twitter"
                      :on-change-text (fn [text]
                                        (swap! local assoc-in [:md] text))}])
       [view {:style {:flex-direction "row"
                      :padding-top    10
                      :padding-bottom 10
                      :padding-left   20
                      :padding-right  20}}
        [touchable-highlight
         {:style    {:background-color "green"
                     :padding-left     20
                     :padding-right    20
                     :padding-top      12
                     :padding-bottom   12
                     :margin-right     20}
          :on-press #(let [put-fn @put-fn-atom
                           new-entry (p/parse-entry (:md @local))
                           new-entry-fn (h/new-entry-fn put-fn new-entry nil)]
                       (new-entry-fn)
                       (swap! local assoc-in [:md] ""))}
         [text {:style {:color       "white"
                        :text-align  "center"
                        :font-weight "bold"}}
          "new"]]
        [touchable-highlight
         {:style    {:background-color "blue"
                     :padding-left     20
                     :padding-right    20
                     :padding-top      12
                     :padding-bottom   12
                     :margin-right     20}
          :on-press #(let [put-fn @put-fn-atom]
                       (dotimes [n 75]
                         (put-fn [:healthkit/steps n])))}
         [text {:style {:color       "white"
                        :text-align  "center"
                        :font-weight "bold"}}
          "steps"]]
        [touchable-highlight
         {:style    {:background-color "blue"
                     :padding-left     20
                     :padding-right    20
                     :padding-top      12
                     :padding-bottom   12
                     :margin-right     20}
          :on-press #(let [put-fn @put-fn-atom]
                       (put-fn [:healthkit/weight]))}
         [text {:style {:color       "white"
                        :text-align  "center"
                        :font-weight "bold"}}
          "weight"]]
        [touchable-highlight
         {:style    {:background-color "#999"
                     :padding-left     20
                     :padding-right    20
                     :padding-top      12
                     :padding-bottom   12}
          :on-press #(let [put-fn @put-fn-atom]
                       (put-fn [:healthkit/bp]))}
         [text {:style {:color       "white"
                        :text-align  "center"
                        :font-weight "bold"}}
          "bp"]]]
       [text {:style {:font-size     10
                      :font-weight   "500"
                      :color         "#CCC"
                      :margin-bottom 20
                      :text-align    "center"}}
        (with-out-str (pp/pprint (second (last (sort-by first @entries)))))]
       #_[image {:source logo-img
                 :style  {:width         80
                          :height        80
                          :margin-bottom 5}}]])))

(defn state-fn [put-fn]
  (let [app-root (app-root put-fn)
        register #(r/reactify-component app-root)]
    (.registerComponent app-registry "meo" register)
    (reset! put-fn-atom put-fn))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
