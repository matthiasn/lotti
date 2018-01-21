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
(def keyboard-avoiding-view (r/adapt-react-class (.-KeyboardAvoidingView react-native)))
(def vibration (.-Vibration react-native))
(def cam-roll (.-CameraRoll react-native))

(defn alert [title] (.alert (.-Alert react-native) title))

(def logo-img (js/require "./images/cljs.png"))

(def react-native-camera (js/require "react-native-camera"))
(def cam (r/adapt-react-class (aget react-native-camera "default")))

(def react-native-vector-icons (js/require "react-native-vector-icons/FontAwesome"))
(def btn (r/adapt-react-class (aget react-native-vector-icons "default" "Button")))
(def icon (r/adapt-react-class (aget react-native-vector-icons "default")))
(def tab-bar-item (r/adapt-react-class (aget react-native-vector-icons "TabBarItemIOS")))

(def kb-aware-scroll-view
  (aget (js/require "react-native-keyboard-aware-scroll-view")
        "KeyboardAwareScrollView"))
(def kb-avoiding-view (r/adapt-react-class kb-aware-scroll-view))

(def react-native-elements (js/require "react-native-elements"))
(def search-bar (r/adapt-react-class (aget react-native-elements "SearchBar")))

(def contacts (js/require "react-native-contacts"))

(def mapbox (aget (js/require "@mapbox/react-native-mapbox-gl") "default"))
(def mapbox-style-url (js->clj (aget mapbox "StyleURL") :keywordize-keys true))
(def map-view (r/adapt-react-class (aget mapbox "MapView")))
