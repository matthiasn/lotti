(ns meo.ui.settings
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-opacity cam contacts
                                   scroll settings-list settings-list-item icon]]
            [cljs-react-navigation.reagent :refer [stack-navigator stack-screen]]
            [re-frame.core :refer [subscribe]]
            [meo.ui.colors :as c]
            [meo.ui.settings.common :refer [settings-icon]]
            [meo.ui.settings.audio :as sa]
            [meo.ui.settings.sync :as ss]
            [meo.ui.settings.health :as sh]
            [meo.ui.settings.theme :as st]
            [meo.ui.settings.db :as sd]
            [meo.ui.settings.contacts :as sc]
            [cljs.pprint :as pp]
            [cljs.tools.reader.edn :as edn]))

(defn settings-wrapper [local put-fn]
  (let [all-timestamps (subscribe [:all-timestamps])
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
         [settings-list {:border-color bg
                         :flex         1}
          [settings-list-item
           {:hasNavArrow      false
            :background-color item-bg
            :title            "Entries"
            :titleStyle       {:color text-color}
            :icon             (settings-icon "list" text-color)
            :title-info       (str (count @all-timestamps))}]
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

(defn dev-settings [local put-fn]
  (let [theme (subscribe [:active-theme])
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (edn/read-string (get qr-code "data"))]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host (:url data)}])
                            (swap! local assoc-in [:cam] false)))]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [settings-list {:border-color bg
                         :width        "100%"}
          [settings-list-item
           {:title            "Scan barcode"
            ;:has-switch       true
            :hasNavArrow      false
            :background-color item-bg
            :titleStyle       {:color text-color}
            :on-press         #(swap! local update-in [:cam] not)}]]
         (when (:cam @local)
           [cam {:style         {:width  "100%"
                                 :flex   5
                                 :height "100%"}
                 :onBarCodeRead on-barcode-read}])

         (when-let [barcode (:barcode @local)]
           [text {:style {:font-size   10
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      5
                          :text-align  "center"}}
            (str barcode)])]))))

(defn settings-tab [local put-fn theme]
  (let [header-bg (get-in c/colors [:header-tab @theme])
        text-color (get-in c/colors [:text @theme])
        list-bg (get-in c/colors [:list-bg @theme])
        opts (fn [title]
               {:title            title
                :headerTitleStyle {:color text-color}
                :animationEnabled false
                :headerStyle      {:backgroundColor header-bg}})]
    (stack-navigator
      {:settings {:screen (stack-screen (settings-wrapper local put-fn)
                                        (opts "Settings"))}
       :theme    {:screen (stack-screen (st/theme-settings-wrapper local put-fn)
                                        (opts "UI Theme"))}
       :contacts {:screen (stack-screen (sc/contact-settings local put-fn)
                                        (opts "Contacts"))}
       :health   {:screen (stack-screen (sh/health-settings local put-fn)
                                        (opts "Health"))}
       :db       {:screen (stack-screen (sd/db-settings local put-fn)
                                        (opts "Database"))}
       :audio    {:screen (stack-screen (sa/audio-settings local put-fn)
                                        (opts "Audio"))}
       :dev      {:screen (stack-screen (dev-settings local put-fn)
                                        (opts "Dev"))}
       :sync     {:screen (stack-screen (ss/sync-settings local put-fn)
                                        (opts "Sync"))}}
      {:cardStyle {:backgroundColor list-bg}})))
