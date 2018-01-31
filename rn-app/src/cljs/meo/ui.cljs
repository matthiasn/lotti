(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.editor :as edit]
            [meo.ui.photos :as photos]
            [meo.ui.shared :refer [view text text-input touchable-highlight btn
                                   tab-bar keyboard-avoiding-view vibration
                                   tab-bar-item app-registry icon safe-area-view]]
            [meo.ui.journal :as jrn]
            [cljs-react-navigation.reagent :refer [tab-navigator]]
            [meo.ui.settings :as ts]
            [meo.ui.colors :as c]))

(def put-fn-atom (r/atom nil))

(def local (r/atom {:cam       false
                    :contacts  (clj->js [])
                    :map-style :Street
                    :md        (str "hello world")}))

(defn app-root []
  (let [theme (subscribe [:active-theme])]
    (fn []
      (let [put-fn @put-fn-atom
            bg (get-in c/colors [:header-tab @theme])]

        [:> (tab-navigator
              {:journal  {:screen            (jrn/journal-tab local put-fn theme)
                          :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                            [icon {:name  "list"
                                                                   :size  22
                                                                   :color tintColor}])}}
               :add      {:screen            (edit/editor-tab local put-fn theme)
                          :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                            [icon {:name  "plus-square-o"
                                                                   :size  26
                                                                   :color tintColor}])}}
               :photos   {:screen            (photos/photos-tab local put-fn theme)
                          :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                            [icon {:name  "film"
                                                                   :size  22
                                                                   :color tintColor}])}}
               :settings {:screen            (ts/settings-tab local put-fn theme)
                          :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                            [icon {:name  "cogs"
                                                                   :size  22
                                                                   :color tintColor}])}}}
              {:swipeEnabled     false
               :animationEnabled false
               :tabBarOptions    {:activeTintColor         "#0078e7"
                                  :activeBackgroundColor   bg
                                  :inactiveBackgroundColor bg
                                  :style                   {:backgroundColor bg}
                                  :tabStyle                {:margin 0}
                                  :inactiveTintColor       "#AAA"
                                  :showLabel               false}})]))))

(defn state-fn [put-fn]
  (reset! put-fn-atom put-fn)
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
