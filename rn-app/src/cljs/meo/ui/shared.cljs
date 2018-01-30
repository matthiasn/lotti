(ns meo.ui.shared
  (:require [reagent.core :as r]))

(def react-native (js/require "react-native"))

(def app-registry (.-AppRegistry react-native))
(def view (r/adapt-react-class (.-View react-native)))
(def scroll (r/adapt-react-class (.-ScrollView react-native)))
(def image (r/adapt-react-class (.-Image react-native)))
(def progress-bar (r/adapt-react-class (.-ProgressBarAndroid react-native)))
(def text (r/adapt-react-class (.-Text react-native)))
(def input (r/adapt-react-class (.-TextInput react-native)))
(def flat-list (r/adapt-react-class (.-FlatList react-native)))
(def touchable (r/adapt-react-class (.-TouchableWithoutFeedback react-native)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight react-native)))
(def text-input (r/adapt-react-class (.-TextInput react-native)))
(def tab-bar (r/adapt-react-class (.-TabBarIOS react-native)))
(def picker (r/adapt-react-class (.-Picker react-native)))
(def picker-item (r/adapt-react-class (aget react-native "Picker" "Item")))
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView react-native)))
(def vibration (.-Vibration react-native))
(def cam-roll (.-CameraRoll react-native))

(defn alert [title] (.alert (.-Alert react-native) title))

(def logo-img (js/require "./images/meo.png"))

(def react-native-camera (js/require "react-native-camera"))
(def cam (r/adapt-react-class (aget react-native-camera "default")))

(def react-native-vector-icons (js/require "react-native-vector-icons/FontAwesome"))
(def btn (r/adapt-react-class (aget react-native-vector-icons "default" "Button")))
(def icon (r/adapt-react-class (aget react-native-vector-icons "default")))
(def tab-bar-item (r/adapt-react-class (aget react-native-vector-icons "TabBarItemIOS")))

(def react-native-elements (js/require "react-native-elements"))
(def search-bar (r/adapt-react-class (aget react-native-elements "SearchBar")))
(def divider (r/adapt-react-class (aget react-native-elements "Divider")))

(def contacts (js/require "react-native-contacts"))

(def react-navigation (js/require "react-navigation"))

(def mapbox-gl (js/require "@mapbox/react-native-mapbox-gl"))
(def mapbox (aget mapbox-gl "default"))
(def mapbox-style-url (js->clj (aget mapbox "StyleURL") :keywordize-keys true))
(def map-view (r/adapt-react-class (aget mapbox "MapView")))

(def rn-settings-list (js/require "react-native-settings-list"))
(def settings-list (r/adapt-react-class rn-settings-list))
(def settings-list-header (r/adapt-react-class (aget rn-settings-list "Header")))
(def settings-list-item (r/adapt-react-class (aget rn-settings-list "Item")))
