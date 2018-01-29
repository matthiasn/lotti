(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.editor :as edit]
            [meo.ui.photos :as photos]
            [meo.ui.shared :refer [view text text-input touchable-highlight btn
                                   tab-bar keyboard-avoiding-view vibration
                                   tab-bar-item app-registry icon]]
            [meo.ui.journal :as jrn]
            [cljs-react-navigation.reagent :refer [tab-navigator]]
            [meo.ui.settings :as ts]))

(def put-fn-atom (r/atom nil))

(def local (r/atom {:cam       false
                    :contacts  (clj->js [])
                    :map-style :Street
                    :md        (str "hello world")}))

(defn app-root []
  (fn []
    (let [put-fn @put-fn-atom]
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
  (reset! put-fn-atom put-fn)
  {:observed rdb/app-db})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
