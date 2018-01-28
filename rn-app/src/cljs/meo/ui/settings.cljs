(ns meo.ui.settings
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight cam contacts
                                   scroll btn flat-list map-view mapbox
                                   mapbox-style-url picker picker-item divider
                                   settings-list settings-list-header
                                   settings-list-item]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [subscribe]]))

(defn render-item [item]
  (let [item (js->clj item :keywordize-keys true)
        contact (:item item)]
    (r/as-element
      [view {:style {:flex             1
                     :background-color :white
                     :margin-top       10
                     :padding          10
                     :width            "100%"}
             :key   (:recordID contact)}
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

(defn settings-wrapper [local put-fn]
  (let [entries (subscribe [:entries])
        reset-state #(put-fn [:state/reset])
        load-state #(put-fn [:state/load])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction "column"
                       :padding-top    10}}
         [settings-list {:border-color :lightgrey
                         :flex         1}
          [settings-list-item {:hasNavArrow false
                               :title       "Entries"
                               :title-info  (count @entries)}]
          [settings-list-item {:hasNavArrow true
                               :title       "Contacts"
                               :on-press    #(navigate "contacts")
                               :title-info  (.-length (:contacts @local))}]
          [settings-list-item {:hasNavArrow true
                               :title       "Health"
                               :on-press    #(navigate "health")}]
          [settings-list-item {:hasNavArrow true
                               :title       "Maps Style"
                               :on-press    #(navigate "map")}]
          [settings-list-item {:title         "Reset"
                               :has-nav-arrow false
                               :on-press      reset-state}]
          [settings-list-item {:title         "Load from database"
                               :has-nav-arrow false
                               :on-press      load-state}]
          [settings-list-item {:has-nav-arrow true
                               :on-press      #(navigate "sync")
                               :title         "Sync"}]]]))))

(defn map-settings-wrapper [local put-fn]
  (fn [{:keys [screenProps navigation] :as props}]
    (let [{:keys [navigate goBack]} navigation]
      [view {:style {:flex-direction "column"
                     :padding-top    10
                     :padding-bottom 10}}
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
                 :on-value-change (fn [v idx]
                                    (let [style (keyword v)]
                                      (swap! local assoc-in [:map-style] style)))}
         (for [[k style] mapbox-style-url]
           ^{:key k}
           [picker-item {:label (name k) :value k}])]]])))

(defn contact-settings [local put-fn]
  (let [read-contacts (fn [_]
                        (let [cb (fn [err contacts]
                                   (swap! local assoc-in [:contacts] contacts))]
                          (.getAll contacts cb)))]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction "column"
                       :padding-top    10
                       :padding-bottom 10}}
         [scroll {}
          [view {:style {:flex-direction "column"
                         :width          "100%"}}
           [settings-list {:border-color :lightgrey
                           :width        "100%"
                           :flex         1}
            [settings-list-item {:title       "Import contacts"
                                 :hasNavArrow false
                                 :on-press    read-contacts}]]
           [flat-list {:data        (:contacts @local)
                       :render-item render-item}]]]]))))

(defn health-settings [local put-fn]
  (let [weight-fn #(put-fn [:healthkit/weight])
        bp-fn #(put-fn [:healthkit/bp])
        steps-fn #(dotimes [n 5] (put-fn [:healthkit/steps n]))
        sleep-fn #(put-fn [:healthkit/sleep])]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation]
        [view {:style {:flex-direction "column"
                       :padding-top    10
                       :padding-bottom 10}}
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
        [view {:style {:flex-direction "column"
                       :padding-top    10}}
         [settings-list {:border-color :lightgrey
                         :width        "100%"
                         :flex         1}
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

(defn settings-tab [local put-fn]
  (stack-navigator
    {:settings {:screen (stack-screen (settings-wrapper local put-fn)
                                      {:title "Settings"})}
     :map      {:screen (stack-screen (map-settings-wrapper local put-fn)
                                      {:title "Map Style"})}
     :contacts {:screen (stack-screen (contact-settings local put-fn)
                                      {:title "Contacts"})}
     :health   {:screen (stack-screen (health-settings local put-fn)
                                      {:title "Health"})}
     :sync     {:screen (stack-screen (sync-settings local put-fn)
                                      {:title "Sync"})}}))
