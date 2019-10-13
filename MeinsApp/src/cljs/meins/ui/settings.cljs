(ns meins.ui.settings
  (:require ["react-native-version-number" :as rnvn]
            ["react-navigation-stack" :refer [createStackNavigator]]
            [meins.ui.icons.settings :as icns]
            [meins.ui.settings.audio :as audio]
            [meins.ui.settings.db :as db]
            [meins.ui.settings.dev :as dev]
            [meins.ui.settings.geolocation :as geo]
            [meins.ui.settings.health :as sh]
            [meins.ui.settings.items :refer [item screen settings-page]]
            [meins.ui.settings.sync :as sync]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]))

(def nav-bg (get-in styles/colors [:nav-bg :dark]))
(def bg (get-in styles/colors [:list-bg :dark]))

(def local (r/atom {:cam      false
                    :contacts (clj->js [])
                    :active   "journal"}))

(defn settings-wrapper [_props]
  (let []
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            icon-size 26]
        [settings-page
         [item {:label "VERSION"
                :icon  (icns/version-icon icon-size)
                :info  (aget rnvn "default" "appVersion")}]
         #_[item {:label "CONTACTS"
                  :icon  (icns/contacts-icon icon-size)
                  :info  0}]
         [item {:label         "HEALTH"
                :icon          (icns/health-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "health")}]
         [item {:label         "THEME"
                :icon          (icns/theme-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "theme")}]
         [item {:label         "DATABASE"
                :icon          (icns/db-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "db")}]
         [item {:label         "ENTRY VIEW"
                :icon          (icns/entries-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "dev")}]
         [item {:label         "GEOLOCATION"
                :icon          (icns/map-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "geo")}]
         [item {:label         "AUDIO"
                :icon          (icns/audio-icon icon-size)
                :has-nav-arrow true
                :on-press      #(navigate "audio")}]
         [item {:label            "SYNC"
                :icon             (icns/sync-icon icon-size)
                :has-nav-arrow    true
                :btm-border-width 0
                :on-press         #(navigate "sync")}]]))))

(def settings-stack
  (createStackNavigator
    (clj->js {:settings      (screen {:title  "Settings"
                                      :screen settings-wrapper})
              :sync          (screen {:title  "Sync"
                                      :screen sync/sync-settings})
              :sync-intro    (screen {:title  "Sync Assistant"
                                      :screen sync/intro})
              :sync-show-qr  (screen {:title  "Sync Assistant"
                                      :screen sync/show-qr})
              :sync-scan-qr  (screen {:title  "Sync Assistant"
                                      :screen sync/scan-qr})
              :sync-success  (screen {:title  "Sync Assistant"
                                      :screen sync/success})
              :sync-advanced (screen {:title  "Sync Advanced"
                                      :screen sync/sync-advanced})
              :dev           (screen {:title  "Entry View"
                                      :screen dev/dev-settings})
              :geo           (screen {:title  "Geolocation"
                                      :screen geo/geo-settings})
              :db            (screen {:title  "Database"
                                      :screen db/db-settings})
              :audio         (screen {:title  "Audio Recorder"
                                      :screen audio/audio-settings})
              :health        (screen {:title  "Health"
                                      :screen sh/health-settings})})
    (clj->js {:defaultNavigationOptions {:headerStyle {:backgroundColor   nav-bg
                                                       :height            60
                                                       :borderBottomWidth 0}}
              :cardStyle                {:backgroundColor bg}
              :initialRouteName         "settings"
              :height                   100
              :headerMode               :float})))
