(ns meins.ui.shared
  (:require ["react-native" :as react-native :refer [Clipboard]]
            ["react-native-modal" :default Modal]
            ["react-native-camera" :as react-native-camera]
            ["react-native-elements" :as react-native-elements]
            ["react-native-settings-list" :as rn-settings-list :refer [Header Item]]
            ["react-native-vector-icons/FontAwesome" :as FontAwesome]
            [reagent.core :as r]))

(def app-registry (.-AppRegistry react-native))
(def dimensions (.-Dimensions react-native))
(def flat-list (r/adapt-react-class (.-FlatList react-native)))
(def image (r/adapt-react-class (.-Image react-native)))
(def input (r/adapt-react-class (.-TextInput react-native)))
(def keyboard (.-Keyboard react-native))
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView react-native)))
(def modal (r/adapt-react-class Modal))
(def picker (r/adapt-react-class (.-Picker react-native)))
(def picker-item (r/adapt-react-class (aget react-native "Picker" "Item")))
(def platform-os (aget react-native "Platform" "OS"))
(def progress-bar (r/adapt-react-class (.-ProgressBarAndroid react-native)))
(def safe-area-view (r/adapt-react-class (.-SafeAreaView react-native)))
(def scroll (r/adapt-react-class (.-ScrollView react-native)))
(def status-bar (r/adapt-react-class (.-StatusBar react-native)))
(def switch (r/adapt-react-class (.-Switch react-native)))
(def tab-bar (r/adapt-react-class (.-TabBarIOS react-native)))
(def text (r/adapt-react-class (.-Text react-native)))
(def text-input (r/adapt-react-class (.-TextInput react-native)))
(def touchable (r/adapt-react-class (.-TouchableWithoutFeedback react-native)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight react-native)))
(def touchable-opacity (r/adapt-react-class (.-TouchableOpacity react-native)))
(def vibration (.-Vibration react-native))
(def view (r/adapt-react-class (.-View react-native)))
(def virtualized-list (r/adapt-react-class (.-VirtualizedList react-native)))

(defn alert [title] (.alert (.-Alert react-native) (str title)))

(defn set-clipboard [s] (.setString Clipboard s))

(def logo-img (js/require "../images/logo.png"))

(def cam (r/adapt-react-class (aget react-native-camera "RNCamera")))

(def fa-icon (r/adapt-react-class (aget FontAwesome "default")))

(def btn (r/adapt-react-class (aget FontAwesome "default" "Button")))
(def tab-bar-item (r/adapt-react-class (aget FontAwesome "TabBarItemIOS")))

(def search-bar (r/adapt-react-class (aget react-native-elements "SearchBar")))
(def divider (r/adapt-react-class (aget react-native-elements "Divider")))

(def contacts (js/require "react-native-contacts"))

(def settings-list (r/adapt-react-class rn-settings-list))
(def settings-list-header (r/adapt-react-class Header))
(def settings-list-item (r/adapt-react-class Item))

(defn settings-icon [icon-name color]
  (r/as-element
    [view {:style {:padding-top  14
                   :padding-left 14
                   :width        44}}
     [fa-icon {:name  icon-name
               :size  20
               :style {:color      color
                       :text-align :center}}]]))
