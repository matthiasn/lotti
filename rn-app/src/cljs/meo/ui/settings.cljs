(ns meo.ui.settings
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight cam contacts
                                   scroll btn flat-list map-view mapbox
                                   mapbox-style-url picker picker-item divider
                                   settings-list settings-list-header
                                   settings-list-item icon]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [subscribe]]
            [meo.ui.colors :as c]))

(defn render-item [item]
  (let [item (js->clj item :keywordize-keys true)
        contact (:item item)]
    (r/as-element
      [view {:style {:flex             1
                     :background-color :white
                     :margin-top       10
                     :padding          10
                     :width            "100%"}}
       [text {:style {:color       "#777"
                      :text-align  "center"
                      :font-weight "bold"
                      :margin-top  5}}
        (:givenName contact) " "
        [text {:style {:font-weight "bold"}}
         (:familyName contact)]]
       [text {:style {:color      "#555"
                      :text-align "center"
                      :font-size  5}}
        (str (select-keys contact [:middleName :phoneNumbers :emailAddresses
                                   :postalAddresses :companyName]))]])))

(defn settings-icon [icon-name color]
  (r/as-element
    [view {:style {:padding-top  14
                   :padding-left 14
                   :width        44}}
     [icon {:name  icon-name
            :size  20
            :style {:color      color
                    :text-align :center}}]]))

(defn settings-wrapper [local put-fn]
  (let [entries (subscribe [:entries])
        theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :height           "100%"
                       :background-color bg}}
         [settings-list {:border-color :lightgrey
                         :flex         1}
          [settings-list-item
           {:hasNavArrow      false
            :background-color item-bg
            :title            "Entries"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "list" text-color)
            :title-info       (str (count @entries))}]
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
            :titleStyle       {:color text-color}
            :title            "Maps Style"
            :icon             (settings-icon "map" text-color)
            :on-press         #(navigate "map")}]
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
            :icon             (settings-icon "refresh" text-color)
            :on-press         #(navigate "sync")
            :title            "Sync"}]]]))))

(defn map-settings-wrapper [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [scroll {}
          [view {:style {:flex-direction "column"
                         :width          "100%"}}
           [map-view {:showUserLocation true
                      :centerCoordinate [9.95 53.55]
                      :styleURL         (get mapbox-style-url (:map-style @local))
                      :style            {:width         "100%"
                                         :flex          2
                                         :height        300
                                         :margin-bottom 10}
                      :zoomLevel        10}]]
          [picker {:selected-value  (:map-style @local)
                   :style {:color "red"}
                   :on-value-change (fn [v idx]
                                      (let [style (keyword v)]
                                        (swap! local assoc-in [:map-style] style)))}
           (for [[k style] mapbox-style-url]
             ^{:key k}
             [picker-item {:style {:color :red}
                           :label (name k) :value k}])]]]))))

(defn theme-settings-wrapper [local put-fn]
  (let [theme (subscribe [:active-theme])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [scroll {}
          [picker {:selected-value  @theme
                   :on-value-change (fn [v idx]
                                      (let [style (keyword v)]
                                        (put-fn [:theme/active style])))}
           [picker-item {:label "light theme"
                         :value :light}]
           [picker-item {:label "dark theme"
                         :value :dark}]]]]))))

(defn contact-settings [local put-fn]
  (let [read-contacts (fn [_]
                        (let [cb (fn [err contacts]
                                   (swap! local assoc-in [:contacts] contacts))]
                          (.getAll contacts cb)))]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color c/light-gray}}
         [scroll {}
          [view {:style {:flex-direction "column"
                         :width          "100%"}}
           [settings-list {:border-color :lightgrey
                           :width        "100%"
                           :flex         1}
            [settings-list-item {:title       "Import contacts"
                                 :hasNavArrow false
                                 :on-press    read-contacts}]]
           [flat-list {:data         (:contacts @local)
                       :render-item  render-item
                       :keyExtractor (fn [item] (.-recordID item))}]]]]))))

(defn health-settings [local put-fn]
  (let [weight-fn #(put-fn [:healthkit/weight])
        bp-fn #(put-fn [:healthkit/bp])
        steps-fn #(dotimes [n 5] (put-fn [:healthkit/steps n]))
        sleep-fn #(put-fn [:healthkit/sleep])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color c/light-gray}}
         [settings-list {:border-color :lightgrey
                         :width        "100%"
                         :flex         1}
          [settings-list-item {:title       "Weight"
                               :hasNavArrow false
                               :on-press    weight-fn}]
          [settings-list-item {:title       "Blood Pressure"
                               :hasNavArrow false
                               :on-press    bp-fn}]
          [settings-list-item {:title       "Steps"
                               :hasNavArrow false
                               :on-press    steps-fn}]
          [settings-list-item {:title       "Sleep"
                               :hasNavArrow false
                               :on-press    sleep-fn}]]]))))

(defn sync-settings [local put-fn]
  (let [on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (get qr-code "data")]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host data}])
                            (swap! local assoc-in [:cam] false)))]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color c/light-gray
                       :height           "100%"}}
         [settings-list {:border-color :lightgrey
                         :width        "100%"}
          [settings-list-item {:title       "Scan barcode"
                               :has-switch  true
                               :hasNavArrow false
                               :on-press    #(swap! local update-in [:cam] not)}]
          [settings-list-item {:title       "Sync"
                               :hasNavArrow false
                               :on-press    #(put-fn [:sync/initiate])}]]
         (when (:cam @local)
           [cam {:style         {:width  "100%"
                                 :height 300}
                 :onBarCodeRead on-barcode-read}])

         (when-let [barcode (:barcode @local)]
           [text {:style {:font-size   10
                          :color       "#888"
                          :font-weight "100"
                          :margin      5
                          :text-align  "center"}}
            (str barcode)])]))))

(defn db-settings [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation
          reset-state #(do (put-fn [:state/reset]) (goBack))
          load-state #(do (put-fn [:state/load]) (goBack))]
      [view {:style {:flex-direction   "column"
                     :padding-top      10
                     :background-color c/light-gray
                     :height           "100%"}}
       [settings-list {:border-color :lightgrey
                       :width        "100%"}
        [settings-list-item {:title       "Reset"
                             :hasNavArrow false
                             :icon        (settings-icon "bolt" "#999")
                             :on-press    reset-state}]
        [settings-list-item {:title       "Load from database"
                             :hasNavArrow false
                             :icon        (settings-icon "spinner" "#999")
                             :on-press    load-state}]]])))

(defn settings-tab [local put-fn theme]
  (let [header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        opts (fn [title]
               {:title            title
                :headerTitleStyle {:color text-color}
                :headerStyle      {:backgroundColor header-bg}})]
    (stack-navigator
      {:settings {:screen (stack-screen (settings-wrapper local put-fn)
                                        (opts "Settings"))}
       :map      {:screen (stack-screen (map-settings-wrapper local put-fn)
                                        (opts "Map Style"))}
       :theme    {:screen (stack-screen (theme-settings-wrapper local put-fn)
                                        (opts "UI Theme"))}
       :contacts {:screen (stack-screen (contact-settings local put-fn)
                                        (opts "Contacts"))}
       :health   {:screen (stack-screen (health-settings local put-fn)
                                        (opts "Health"))}
       :db       {:screen (stack-screen (db-settings local put-fn)
                                        (opts "Database"))}
       :sync     {:screen (stack-screen (sync-settings local put-fn)
                                        (opts "Sync"))}})))
