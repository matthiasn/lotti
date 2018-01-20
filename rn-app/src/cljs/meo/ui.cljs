(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.tab-bar :as tb]
            [meo.ui.editor :as edit]
            [meo.ui.settings :as ts]
            [meo.ui.health :as uh]
            [cljs.pprint :as pp]))

(def ReactNative (js/require "react-native"))

(def app-registry (.-AppRegistry ReactNative))
(def text (r/adapt-react-class (.-Text ReactNative)))
(def view (r/adapt-react-class (.-View ReactNative)))
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView ReactNative)))
(def react-native-camera (js/require "react-native-camera"))
(def cam (r/adapt-react-class (aget react-native-camera "default")))

(def kb-aware-scroll-view
  (aget (js/require "react-native-keyboard-aware-scroll-view")
        "KeyboardAwareScrollView"))
(def kb-avoiding-view (r/adapt-react-class kb-aware-scroll-view))

(def image (r/adapt-react-class (.-Image ReactNative)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight ReactNative)))
(def logo-img (js/require "./images/cljs.png"))
(def text-input (r/adapt-react-class (.-TextInput ReactNative)))

(def react-native-vector-icons (js/require "react-native-vector-icons/FontAwesome"))
(def icon (r/adapt-react-class (aget react-native-vector-icons "default")))
(def tab-bar-item (r/adapt-react-class (aget react-native-vector-icons "TabBarItemIOS")))

(defn alert [title]
  (.alert (.-Alert ReactNative) title))

(reg-sub :entries (fn [db _] (:entries db)))

(defn app-root [put-fn]
  (let [local (r/atom {:cam        false
                       :active-tab :main
                       :md         (str "hello world")})]
    (fn [_put-fn]
      [keyboard-avoiding-view
       {:behavior "padding"
        :style    {:display          "flex"
                   :flex-direction   "column"
                   :justify-content  "space-between"
                   :background-color "#EEE"
                   :padding-top      30
                   :flex             1
                   :align-items      "center"}}
       [uh/health-page local put-fn]
       [ts/settings-page local put-fn]
       [edit/editor local put-fn]
       [tb/meo-tab-bar local put-fn]])))

(defn state-fn [put-fn]
  (let [app-root (app-root put-fn)
        register #(r/reactify-component app-root)]
    (.registerComponent app-registry "meo" register))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
