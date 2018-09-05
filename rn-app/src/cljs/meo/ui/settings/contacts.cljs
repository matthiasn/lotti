(ns meo.ui.settings.contacts
  (:require [meo.ui.colors :as c]
            [meo.ui.shared :refer [view text contacts scroll btn flat-list settings-list settings-list-item]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]))

(defn render-item [text-color item-bg]
  (fn [item]
    (let [item (js->clj item :keywordize-keys true)
          contact (:item item)]
      (r/as-element
        [view {:style {:flex             1
                       :background-color item-bg
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
         [text {:style {:color      text-color
                        :text-align "center"
                        :font-size  5}}
          (str (select-keys contact [:middleName :phoneNumbers :emailAddresses
                                     :postalAddresses :companyName]))]]))))

(defn contact-settings [local put-fn]
  (let [theme (subscribe [:active-theme])
        read-contacts (fn [_]
                        (let [cb (fn [err contacts]
                                   (swap! local assoc-in [:contacts] contacts))]
                          (.getAll contacts cb)))]
    (fn [{:keys [screenProps navigation] :as props}]
      (let [{:keys [navigate goBack]} navigation
            bg (get-in c/colors [:list-bg @theme])
            item-bg (get-in c/colors [:text-bg @theme])
            text-color (get-in c/colors [:text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :padding-bottom   10
                       :height           "100%"
                       :background-color bg}}
         [scroll {}
          [view {:style {:flex-direction "column"
                         :width          "100%"}}
           [settings-list {:border-color bg
                           :width        "100%"
                           :flex         1}
            [settings-list-item {:title            "Import contacts"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :on-press         read-contacts}]]
           [flat-list {:data         (:contacts @local)
                       :render-item  (render-item text-color item-bg)
                       :keyExtractor (fn [item] (.-recordID item))}]]]]))))
