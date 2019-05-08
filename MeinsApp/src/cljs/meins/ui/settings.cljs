(ns meins.ui.settings
  (:require [reagent.core :as r]
            ["react-navigation" :refer [createStackNavigator createAppContainer
                                        createBottomTabNavigator]]
            ["react-native-vector-icons/FontAwesome" :as FontAwesome]
            [re-frame.core :refer [reg-sub subscribe]]
            [meins.ui.shared :refer [view text fa-icon settings-list alert
                                     settings-list-header settings-list-item]]
            [meins.ui.settings.db :as db]
            [meins.ui.settings.sync :as sync]
            [meins.ui.settings.dev :as dev]
            [meins.ui.settings.health :as sh]
            [meins.ui.colors :as c]
            [cljs.pprint :as pp]))

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

(def put-fn-atom (r/atom nil))

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
                                  :size             22
                                  :background-color "#445"
                                  :color            (:tintColor m)}])))})

(defn put-fn [])

(defn settings-icon [icon-name color]
  (r/as-element
    [view {:style {:padding-top  14
                   :padding-left 14
                   :width        44}}
     [fa-icon {:name  icon-name
               :size  20
               :style {:color      color
                       :text-align :center}}]]))

(defn settings-wrapper [props]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [navigation] :as props}]
      (let [{:keys [navigate goBack] :as n} (js->clj navigation :keywordize-keys true)
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:button-bg @theme])
            header-color (get-in c/colors [:header-text @theme])
            text-color (get-in c/colors [:btn-text @theme])]
        [view {:style {:flex-direction   "column"
                       :height           "100%"
                       :background-color bg}}
         [settings-list {:border-color bg
                         :flex         1}
          [settings-list-header
           {:headerText       "Settings"
            :background-color item-bg
            :headerStyle      {:color       header-color
                               :font-weight :bold
                               :text-align  "center"
                               :font-size   36}}]
          [settings-list-item
           {:hasNavArrow      false
            :background-color item-bg
            :title            "Entries"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "list" text-color)
            ;:title-info       (str (count @all-timestamps))
            }]
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
            :title            "Dev"}]
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
              :db       {:screen (r/reactify-component db/db-settings)}
              :health   {:screen (r/reactify-component sh/health-settings)}})
    (clj->js {;:headerMode "none"
              :defaultNavigationOptions {:headerStyle {:backgroundColor   "#445"
                                                       :borderBottomWidth 0}}})))
