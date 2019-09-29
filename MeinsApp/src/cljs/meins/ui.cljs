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
            [meins.ui.styles :as styles]
            [meins.ui.photos :as photos]
            [meins.ui.journal :as jrn]
            [meins.ui.editor :as ue]
            [meins.ui.icons :as ico]))

(reg-sub :active-theme (fn [_db _] :dark))

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
                    (let [m (js->clj m :keywordize-keys true)
                          color (:tintColor m)]
                      (r/as-element
                        (case icon-name
                          "journal" [ico/journal-icon size color]
                          "new-entry" [ico/add-icon size color]
                          "photos" [ico/photos-icon size color]
                          "settings" [ico/settings-icon size color]))))})

(defn put-fn [])

(def bg (get-in styles/colors [:nav-bg :dark]))

(defn opts [title]
  {:title            title
   :headerTitleStyle {:color "white"}
   :animationEnabled false
   :headerStyle      {:backgroundColor bg}})

(def app-nav
  (createBottomTabNavigator
    (clj->js {:Journal  {:screen            jrn/journal-stack
                         :navigationOptions (nav-options "journal" 36)}
              :Add      {:screen            (r/reactify-component ue/editor)
                         :navigationOptions (nav-options "new-entry" 36)}
              :Photos   {:screen            (r/reactify-component photos/photos-tab)
                         :navigationOptions (nav-options "photos" 36)}
              :Settings {:screen            s/settings-stack
                         :navigationOptions (nav-options "settings" 36)}})
    (clj->js {:initialRouteName "Journal"
              :transitionConfig (fn []
                                  (clj->js
                                    {:transitionSpec
                                     {:duration 0
                                      :timing   (.-timing Animated)}}))
              :tabBarOptions    {:activeTintColor         "#FFF"
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
  (reset! db/emit-atom put-fn)
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
