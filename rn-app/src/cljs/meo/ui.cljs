(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.editor :as edit]
            [meo.ui.photos :as photos]
            [meo.ui.shared :refer [view text text-input touchable-highlight btn
                                   tab-bar keyboard-avoiding-view vibration
                                   tab-bar-item app-registry view icon]]
            [meo.ui.journal :as jrn]
            [cljs-react-navigation.reagent :refer [tab-navigator]]
            [meo.ui.settings :as ts]))

(reg-sub :entries (fn [db _] (:entries db)))

(defn app-root [put-fn]
  (let [local (r/atom {:cam       false
                       :contacts  (clj->js [])
                       :map-style :Street
                       :md        (str "hello world")})]
    (fn [_put-fn]
      [:> (tab-navigator
            {:journal  {:screen            (jrn/journal-tab local put-fn)
                        :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                          [icon {:name  "list"
                                                                 :size  20
                                                                 :color tintColor}])}}
             :add      {:screen            (edit/editor-tab local put-fn)
                        :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                          [icon {:name  "plus-square-o"
                                                                 :size  20
                                                                 :color tintColor}])}}
             :photos   {:screen            (photos/photos-tab local put-fn)
                        :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                          [icon {:name  "film"
                                                                 :size  20
                                                                 :color tintColor}])}}
             :settings {:screen            (ts/settings-tab local put-fn)
                        :navigationOptions {:tabBarIcon (fn [{:keys [tintColor]}]
                                                          [icon {:name  "cogs"
                                                                 :size  20
                                                                 :color tintColor}])}}}
            {:swipeEnabled     true
             :animationEnabled true
             :tabBarOptions    {:activeTintColor   "#0078e7"
                                :inactiveTintColor "#AAA"
                                :showLabel         false}})])))

(defn state-fn [put-fn]
  (let [app-root (app-root put-fn)
        register #(r/reactify-component app-root)]
    (.registerComponent app-registry "meo" register))
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
