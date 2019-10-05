(ns meins.ui.settings
  (:require ["react-native-version-number" :as rnvn]
            ["react-navigation-stack" :refer [createStackNavigator]]
            [meins.ui.settings.audio :as audio]
            [meins.ui.settings.db :as db]
            [meins.ui.settings.dev :as dev]
            [meins.ui.settings.geolocation :as geo]
            [meins.ui.settings.health :as sh]
            [meins.ui.settings.items :refer [item screen] :as items]
            [meins.ui.settings.sync :as sync]
            [meins.ui.shared :refer [fa-icon settings-icon status-bar text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [reg-sub subscribe]]
            [reagent.core :as r]))

(def nav-bg (get-in styles/colors [:nav-bg :dark]))
(def bg (get-in styles/colors [:list-bg :dark]))

(def local (r/atom {:cam      false
                    :contacts (clj->js [])
                    :active   "journal"}))

(defn settings-wrapper [_props]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:display          "flex"
                       :flex-direction   "column"
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [view {:style {:display       :flex
                        :padding-left  24
                        :padding-right 24
                        :height        "100%"}}
          [item {:label "VERSION"
                 :info  (aget rnvn "default" "appVersion")}]
          [item {:label "CONTACTS"
                 :info  0}]
          [item {:label         "HEALTH"
                 :has-nav-arrow true
                 :on-press      #(navigate "health")}]
          [item {:label         "THEME"
                 :has-nav-arrow true
                 :on-press      #(navigate "theme")}]
          [item {:label         "DATABASE"
                 :has-nav-arrow true
                 :on-press      #(navigate "db")}]
          [item {:label         "ENTRY VIEW"
                 :has-nav-arrow true
                 :on-press      #(navigate "dev")}]
          [item {:label         "GEOLOCATION"
                 :has-nav-arrow true
                 :on-press      #(navigate "geo")}]
          [item {:label         "AUDIO"
                 :has-nav-arrow true
                 :on-press      #(navigate "audio")}]
          [item {:label         "SYNC"
                 :has-nav-arrow true
                 :on-press      #(navigate "sync")}]]]))))

(def settings-stack
  (createStackNavigator
    (clj->js {:settings     (screen {:title  "Settings"
                                     :screen settings-wrapper})
              :sync         (screen {:title  "Sync"
                                     :screen sync/sync-settings})
              :sync-intro   (screen {:title  "Sync Assistant"
                                     :screen sync/intro})
              :sync-show-qr (screen {:title  "Sync Assistant"
                                     :screen sync/show-qr})
              :sync-scan-qr (screen {:title  "Sync Assistant"
                                     :screen sync/scan-qr})
              :sync-success (screen {:title  "Sync Assistant"
                                     :screen sync/success})
              :dev          (screen {:title  "Entry View"
                                     :screen dev/dev-settings})
              :geo          (screen {:title  "Geolocation"
                                     :screen geo/geo-settings})
              :db           (screen {:title  "Database"
                                     :screen db/db-settings})
              :audio        (screen {:title  "Audio Recorder"
                                     :screen audio/audio-settings})
              :health       (screen {:title  "Health"
                                     :screen sh/health-settings})})
    (clj->js {:defaultNavigationOptions {:headerStyle {:backgroundColor   nav-bg
                                                       :height            60
                                                       :borderBottomWidth 0}}
              :cardStyle                {:backgroundColor bg}
              :initialRouteName         "settings"
              :height                   100
              :headerMode               :float})))
