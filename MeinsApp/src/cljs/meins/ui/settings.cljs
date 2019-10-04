(ns meins.ui.settings
  (:require ["react-native-version-number" :as rnvn]
            ["react-navigation-stack" :refer [createStackNavigator]]
            [meins.ui.settings.audio :as audio]
            [meins.ui.settings.db :as db]
            [meins.ui.settings.dev :as dev]
            [meins.ui.settings.geolocation :as geo]
            [meins.ui.settings.health :as sh]
            [meins.ui.settings.sync :as sync]
            [meins.ui.shared :refer [fa-icon settings-icon status-bar text touchable-opacity view]]
            [meins.ui.styles :as styles]
            [re-frame.core :refer [reg-sub subscribe]]
            [reagent.core :as r]))

(def nav-bg (get-in styles/colors [:nav-bg :dark]))

(def local (r/atom {:cam      false
                    :contacts (clj->js [])
                    :active   "journal"}))

(defn item [_]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [label info on-press]}]
      (let [header-color (get-in styles/colors [:header-text @theme])]
        [touchable-opacity {:on-press on-press
                            :style    {:color             header-color
                                       :margin-left       9
                                       :margin-right      15
                                       :margin-top        23
                                       :display           :flex
                                       :borderBottomColor "#BBBDBF"
                                       :borderBottomWidth 0.5
                                       :flex-direction    :row
                                       :justify-content   :space-between}}
         [text {:style {:font-size      12
                        :line-height    22
                        :padding-bottom 13
                        :font-family    "Montserrat-Regular"
                        :text-align     "center"
                        :opacity        0.68
                        :color          "white"}}
          label]
         (if info
           [text {:style {:font-size   12
                          :line-height 22
                          :font-family "Montserrat-Medium"
                          :text-align  "center"
                          :color       "white"}}
            info]
           [fa-icon {:name  "angle-right"
                     :size  30
                     :style {:color       "#BBBDBF"
                             :margin-left 25}}])]))))

(defn settings-wrapper [_props]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            bg (get-in styles/colors [:list-bg @theme])
            nav-bg (get-in styles/colors [:nav-bg :dark])
            header-color (get-in styles/colors [:header-text @theme])]
        [view {:style {:display          "flex"
                       :flex-direction   "column"
                       :height           "100%"
                       :background-color nav-bg}}
         [status-bar {:barStyle "light-content"}]
         [text {:style {:font-size      18
                        :line-height    22
                        :padding-bottom 20
                        :letter-spacing 0.02
                        :font-family    "Montserrat-SemiBold"
                        :text-align     "center"
                        :color          "white"}}
          "Settings"]
         [view {
                :background-color bg
                :style            {:color         header-color
                                   :display       :flex
                                   :padding-left  24
                                   :padding-right 24
                                   :height        "100%"}}
          [item {:label "VERSION"
                 :info  (aget rnvn "default" "appVersion")}]
          [item {:label "CONTACTS"
                 :info  0}]
          [item {:label    "HEALTH"
                 :on-press #(navigate "health")}]
          [item {:label    "THEME"
                 :on-press #(navigate "theme")}]
          [item {:label    "DATABASE"
                 :on-press #(navigate "db")}]
          [item {:label    "ENTRY VIEW"
                 :on-press #(navigate "dev")}]
          [item {:label    "GEOLOCATION"
                 :on-press #(navigate "geo")}]
          [item {:label    "AUDIO"
                 :on-press #(navigate "audio")}]
          [item {:label    "SYNC"
                 :on-press #(navigate "sync")}]]]))))

(def settings-stack
  (createStackNavigator
    (clj->js {:settings {:screen (r/reactify-component settings-wrapper)}
              :sync     {:screen (r/reactify-component sync/sync-settings)}
              :dev      {:screen (r/reactify-component dev/dev-settings)}
              :geo      {:screen (r/reactify-component geo/geo-settings)}
              :db       {:screen (r/reactify-component db/db-settings)}
              :audio    {:screen (r/reactify-component audio/audio-settings)}
              :health   {:screen (r/reactify-component sh/health-settings)}})
    (clj->js {:defaultNavigationOptions {:headerStyle {:backgroundColor   nav-bg
                                                       :borderBottomWidth 0}}})))
