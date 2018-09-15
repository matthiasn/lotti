(ns meo.ui
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [re-frame.db :as rdb]
            [meo.ui.editor :as edit]
            [meo.ui.photos2 :as photos]
            [meo.ui.shared :refer [view text text-input touchable-opacity btn
                                   tab-bar keyboard-avoiding-view vibration alert
                                   tab-bar-item app-registry icon safe-area-view]]
            [meo.ui.journal :as jrn]
            [cljs-react-navigation.reagent :refer [tab-navigator]]
            [meo.ui.settings :as ts]
            [meo.ui.colors :as c]
            [clojure.pprint :as pp]))

(def put-fn-atom (r/atom nil))

(def local (r/atom {:cam       false
                    :contacts  (clj->js [])
                    :map-style :Street
                    :active    "journal"
                    :md        ""}))

(defn nav-options [icon-name size]
  {:tabBarOnPress (fn [ev]
                    (let [ev (js->clj ev :keywordize-keys true)
                          jumpToIndex (:jumpToIndex ev)]
                      ;(alert (with-out-str (pp/pprint (:scene ev))))
                      (swap! local assoc :active (-> ev :scene :route :routeName))
                      (jumpToIndex (-> ev :scene :index))))
   :tabBarIcon    (fn [{:keys [tintColor]}]
                    [icon {:name  icon-name
                           :size  size
                           :color tintColor}])})

(defn app-root []
  (let [theme (subscribe [:active-theme])]
    (fn []
      (let [put-fn @put-fn-atom
            bg (get-in c/colors [:header-tab @theme])]
        [:> (tab-navigator
              {:journal  {:screen            (jrn/journal-tab local put-fn theme)
                          :navigationOptions (nav-options "list" 22)}
               :add      {:screen            (edit/editor-tab local put-fn theme)
                          :navigationOptions (nav-options "plus-square-o" 26)}
               :photos   {:screen            (photos/photos-tab local put-fn theme)
                          :navigationOptions (nav-options "film" 22)}
               :settings {:screen            (ts/settings-tab local put-fn theme)
                          :navigationOptions (nav-options "cogs" 22)}}
              {:swipeEnabled     false
               :animationEnabled false
               ;:initialRouteName (:active @local) ; not working properly, flickers
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
