(ns settings
  (:require ["react-native" :refer [AppRegistry Platform StyleSheet Text View Icon]]
            ["react" :as react :refer [Component]]
            [reagent.core :as r]
            ["react-navigation" :refer [createStackNavigator createAppContainer
                                        createBottomTabNavigator]]
            ["react-native-vector-icons/FontAwesome" :as FontAwesome]
            ["react-native-settings-list" :as rn-settings-list :refer [Header Item]]
            [re-frame.core :refer [reg-sub subscribe]]
            [cljs.pprint :as pp]))

(def bg "#223")

(def view (r/adapt-react-class View))
(def text (r/adapt-react-class Text))
(def icon (r/adapt-react-class Icon))
(def fa-icon (r/adapt-react-class (aget FontAwesome "default")))

(def settings-list (r/adapt-react-class rn-settings-list))
(def settings-list-header (r/adapt-react-class Header))
(def settings-list-item (r/adapt-react-class Item))

(def instructions
  (.select Platform
           (clj->js {:ios     " Press Cmd+R to reload, Cmd+D or shake for dev menu"
                     :android " Double tap R on your keyboard to reload,\n Shake or press menu button for dev menu"})))

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
  (let [;all-timestamps (subscribe [:all-timestamps])
        ;theme (subscribe [:active-theme])
        ]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg "#445"                                       ;(get-in c/colors [:list-bg @theme])
            item-bg "#556"                                  ;(get-in c/colors [:text-bg @theme])
            text-color "white"                              ;(get-in c/colors [:text @theme])
            ]
        [view {:style {:flex-direction   "column"
                       :padding-top      32
                       :height           "100%"
                       :background-color bg}}
         [settings-list {:border-color bg
                         :flex         1}
          [settings-list-header
           {:headerText       "Settings"
            :background-color item-bg
            :headerStyle      {:color      text-color
                               :text-align "center"
                               :font-size  22}}]
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
            :title-info       (.-length (:contacts @local))}]
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
    (clj->js {:Settings {:screen (r/reactify-component settings-wrapper)}})
    (clj->js {:headerMode "none"})))
