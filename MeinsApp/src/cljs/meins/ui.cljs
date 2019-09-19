(ns meins.ui
  (:require [reagent.core :as r]
            [re-frame.db :as rdb]
            ["react-native" :refer [AppRegistry Platform Animated]]
            ["react" :refer [Component]]
            ["react-navigation" :refer [createAppContainer]]
            ["react-navigation-tabs" :refer [createBottomTabNavigator]]
            [re-frame.core :refer [reg-sub]]
            [meins.ui.shared :refer [view text fa-icon]]
            [meins.ui.settings :as s]
            [meins.ui.db :as db]
            [meins.ui.colors :as c]
            [meins.ui.photos :as photos]
            [meins.ui.journal :as jrn]
            [meins.ui.editor :as ue]))

(def put-fn-atom (r/atom nil))
(reg-sub :active-theme (fn [_db _] :dark))

(def instructions
  (.select Platform
           (clj->js {:ios     " Press Cmd+R to reload, Cmd+D or shake for dev menu"
                     :android " Double tap R on your keyboard to reload,\n Shake or press menu button for dev menu"})))

(def styles
  {:container    {:flex            1
                  :justifyContent  "center"
                  :alignItems      "center"
                  :backgroundColor "#445"}
   :welcome      {:fontSize    44
                  :font-weight "bold"
                  :color       "#FF8C00"
                  :textAlign   "center"
                  :margin      10}
   :instructions {:textAlign    "center"
                  :color        "rgb(66, 184, 221)"
                  :marginBottom 5}})

(defn add-screen []
  [view {:style (:container styles)}
   [text {:style (:welcome styles)}
    "Add Screen"]
   [text {:style (:instructions styles)}
    instructions]])

(def local (r/atom {:cam       false
                    :contacts  (clj->js [])
                    :map-style :Street
                    :active    "journal"
                    :md        ""}))

(defn nav-options [icon-name size]
  {:tabBarOnPress (fn [ev]
                    (let [ev (js->clj ev :keywordize-keys true)
                          navigate (-> ev :navigation :navigate)
                          route-name (-> ev :navigation :state :routeName)]
                      (swap! local assoc :active route-name)
                      (navigate route-name)))
   :tabBarIcon    (fn [m]
                    (let [m (js->clj m :keywordize-keys true)]
                      (r/as-element
                        [fa-icon {:name             icon-name
                                  :size             size
                                  :background-color "#2C3246"
                                  :color            (:tintColor m)}])))})

(defn put-fn [])

(def bg (get-in c/colors [:nav-bg :dark]))

(defn opts [title]
  {:title            title
   :headerTitleStyle {:color "white"}
   :animationEnabled false
   :headerStyle      {:backgroundColor bg}})

(def app-nav
  (createBottomTabNavigator
    (clj->js {:Journal  {:screen            jrn/journal-stack
                         :navigationOptions (nav-options "list" 28)}
              :Add      {:screen            (r/reactify-component ue/editor)
                         :navigationOptions (nav-options "plus-square-o" 28)}
              :Photos   {:screen            (r/reactify-component photos/photos-tab)
                         :navigationOptions (nav-options "film" 28)}
              :Settings {:screen            s/settings-stack
                         :navigationOptions (nav-options "cogs" 28)}})
    (clj->js {:initialRouteName "Journal"
              :transitionConfig (fn []
                                  (clj->js
                                    {:transitionSpec
                                     {:duration 0
                                      :timing   (.-timing Animated)}}))
              :tabBarOptions    {:activeTintColor         "#FEFEFE"
                                 :inactiveTintColor       "#999"
                                 :activeBackgroundColor   bg
                                 :inactiveBackgroundColor bg
                                 :showLabel               false
                                 :tabStyle {:fontSize 100}
                                 :style                   {:backgroundColor bg
                                                           :height          60
                                                           :borderTopColor  "#393F56"
                                                           :borderTopWidth  2}}})))

(def app-container
  (createAppContainer app-nav))

(defn state-fn [put-fn]
  (reset! put-fn-atom put-fn)
  (reset! db/emit-atom put-fn)
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
