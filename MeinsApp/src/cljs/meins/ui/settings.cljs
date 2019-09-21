(ns meins.ui.settings
  (:require [reagent.core :as r]
            ["react-navigation-stack" :refer [createStackNavigator]]
            ["react-native-version-number" :as rnvn]
            [re-frame.core :refer [reg-sub subscribe]]
            [meins.ui.shared :refer [view fa-icon settings-list settings-icon
                                     settings-list-header settings-list-item status-bar]]
            [meins.ui.settings.db :as db]
            [meins.ui.settings.audio :as audio]
            [meins.ui.settings.sync :as sync]
            [meins.ui.settings.dev :as dev]
            [meins.ui.settings.geolocation :as geo]
            [meins.ui.settings.health :as sh]
            [meins.ui.styles :as styles]))

(def bg (get-in styles/colors [:list-bg :dark]))

(def local (r/atom {:cam       false
                    :contacts  (clj->js [])
                    :active    "journal"}))

(defn nav-options [icon-name _size]
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
                                  :size             22
                                  :background-color bg
                                  :color            (:tintColor m)}])))})

(defn settings-wrapper [_props]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            bg (get-in styles/colors [:list-bg @theme])
            item-bg (get-in styles/colors [:button-bg @theme])
            header-color (get-in styles/colors [:header-text @theme])
            text-color (get-in styles/colors [:btn-text @theme])]
        [view {:style {:flex-direction   "column"
                       :height           "100%"
                       :background-color bg}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :flex         1}
          [settings-list-header
           {:headerText       "Settings"
            :background-color item-bg
            :headerStyle      {:color       header-color
                               :font-weight 300
                               :text-align  "center"
                               :font-size   24}}]
          [settings-list-item
           {:hasNavArrow      false
            :background-color item-bg
            :title            "Version"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "list" text-color)
            :title-info       (aget rnvn "default" "appVersion")}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :title            "Contacts"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "address-book" text-color)
            :on-press         #(navigate "contacts")
            :title-info       (str (.-length (:contacts @local)))}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :titleStyle       {:color text-color}
            :title            "Health"
            :icon             (settings-icon "heartbeat" text-color)
            :on-press         #(navigate "health")}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :title            "Theme"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "font" text-color)
            :on-press         #(navigate "theme")}]
          [settings-list-item
           {:title            "Database"
            :background-color item-bg
            :hasNavArrow      true
            :titleStyle       {:color text-color}
            :icon             (settings-icon "database" text-color)
            :on-press         #(navigate "db")}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :titleStyle       {:color text-color}
            :icon             (settings-icon "bug" text-color)
            :on-press         #(navigate "dev")
            :title            "Entry View"}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :titleStyle       {:color text-color}
            :icon             (settings-icon "map" text-color)
            :on-press         #(navigate "geo")
            :title            "Geolocation"}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :titleStyle       {:color text-color}
            :icon             (settings-icon "microphone" text-color)
            :on-press         #(navigate "audio")
            :title            "Audio"}]
          [settings-list-item
           {:hasNavArrow      true
            :background-color item-bg
            :titleStyle       {:color text-color}
            :icon             (settings-icon "refresh" text-color)
            :on-press         #(navigate "sync")
            :title            "Sync"}]]]))))

(def settings-stack
  (createStackNavigator
    (clj->js {:settings {:screen (r/reactify-component settings-wrapper)}
              :sync     {:screen (r/reactify-component sync/sync-settings)}
              :dev      {:screen (r/reactify-component dev/dev-settings)}
              :geo      {:screen (r/reactify-component geo/geo-settings)}
              :db       {:screen (r/reactify-component db/db-settings)}
              :audio    {:screen (r/reactify-component audio/audio-settings)}
              :health   {:screen (r/reactify-component sh/health-settings)}})
    (clj->js {:defaultNavigationOptions {:headerStyle {:backgroundColor   bg
                                                       :borderBottomWidth 0}}})))
