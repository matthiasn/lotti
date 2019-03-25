(ns core
  (:require ["react-native" :refer [AppRegistry Platform StyleSheet Text View]]
            ["react" :as react :refer [Component]]
            [reagent.core :as r]))

(def view (r/adapt-react-class View))
(def text (r/adapt-react-class Text))

(def instructions
  (.select Platform
           (clj->js {:ios     " Press Cmd+R to reload, Cmd+D or shake for dev menu"
                     :android " Double tap R on your keyboard to reload,\n Shake or press menu button for dev menu"})))

(def styles
  {:container    {:flex            1
                  :justifyContent  "center"
                  :alignItems      "center"
                  :backgroundColor "#445"}
   :welcome      {:fontSize  20
                  :color     "#FF8C00"
                  :textAlign "center"
                  :margin    10,}
   :instructions {:textAlign    "center"
                  :color        "rgb(66, 184, 221)"
                  :marginBottom 5}})

(defn app-root []
  [view {:style (:container styles)}
   [text {:style (:welcome styles)}
    "Welcome to React Native"]
   [text {:style (:instructions styles)}
    instructions]])

(defn init ^:dev/after-load []
  (.registerComponent
    AppRegistry "MeinsApp" #(r/reactify-component app-root)))
