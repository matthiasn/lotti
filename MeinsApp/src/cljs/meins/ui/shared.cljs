(ns meins.ui.shared
  (:require [reagent.core :as r]
            ["react-native" :as react-native]
            ["react-native-audio-recorder-player" :as react-native-audio-recorder-player]
            ["react-native-camera" :as react-native-camera]
            ["react-native-vector-icons/FontAwesome" :as FontAwesome]
            ["@mapbox/react-native-mapbox-gl" :as mapbox-gl]
            ["react-native-settings-list" :as rn-settings-list :refer [Header Item]]
            ["react-native-elements" :as react-native-elements]))

(def dimensions (.-Dimensions react-native))
(def keyboard (.-Keyboard react-native))
(def app-registry (.-AppRegistry react-native))
(def view (r/adapt-react-class (.-View react-native)))
(def safe-area-view (r/adapt-react-class (.-SafeAreaView react-native)))
(def scroll (r/adapt-react-class (.-ScrollView react-native)))
(def image (r/adapt-react-class (.-Image react-native)))
(def progress-bar (r/adapt-react-class (.-ProgressBarAndroid react-native)))
(def text (r/adapt-react-class (.-Text react-native)))
(def input (r/adapt-react-class (.-TextInput react-native)))
(def flat-list (r/adapt-react-class (.-FlatList react-native)))
(def touchable (r/adapt-react-class (.-TouchableWithoutFeedback react-native)))
(def touchable-highlight (r/adapt-react-class (.-TouchableHighlight react-native)))
(def touchable-opacity (r/adapt-react-class (.-TouchableOpacity react-native)))
(def text-input (r/adapt-react-class (.-TextInput react-native)))
(def tab-bar (r/adapt-react-class (.-TabBarIOS react-native)))
(def picker (r/adapt-react-class (.-Picker react-native)))
(def picker-item (r/adapt-react-class (aget react-native "Picker" "Item")))
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView react-native)))
(def vibration (.-Vibration react-native))
(def cam-roll (.-CameraRoll react-native))

(defn alert [title] (.alert (.-Alert react-native) (str title)))

(def logo-img (js/require "../images/meo.png"))

(def rn-audio-recorder-player (aget react-native-audio-recorder-player "default"))

(def react-native-camera (js/require "react-native-camera"))
(def cam (r/adapt-react-class (aget react-native-camera "default")))

(def fa-icon (r/adapt-react-class (aget FontAwesome "default")))

(def btn (r/adapt-react-class (aget FontAwesome "default" "Button")))
(def tab-bar-item (r/adapt-react-class (aget FontAwesome "TabBarItemIOS")))

(def search-bar (r/adapt-react-class (aget react-native-elements "SearchBar")))
(def divider (r/adapt-react-class (aget react-native-elements "Divider")))

(def contacts (js/require "react-native-contacts"))

(def mapbox (aget mapbox-gl "default"))
(def mapbox-style-url (js->clj (aget mapbox "StyleURL") :keywordize-keys true))
(def map-view (r/adapt-react-class (aget mapbox "MapView")))
(def point-annotation (r/adapt-react-class (aget mapbox "PointAnnotation")))

(def settings-list (r/adapt-react-class rn-settings-list))
(def settings-list-header (r/adapt-react-class Header))
(def settings-list-item (r/adapt-react-class Item))
