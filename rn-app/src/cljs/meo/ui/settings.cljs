(ns meo.ui.settings
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight cam contacts
                                   scroll btn flat-list map-view mapbox
                                   mapbox-style-url picker picker-item divider]]
            [re-frame.core :refer [subscribe]]
            [clojure.pprint :as pp]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

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
        (str contact)]])))

(defn settings-page [local put-fn]
  (let [entries (subscribe [:entries])
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (get qr-code "data")]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host data}])
                            (swap! local assoc-in [:cam] false)))
        read-contacts (fn [_]
                        (let [cb (fn [err contacts]
                                   (swap! local assoc-in [:contacts] contacts))]
                          (.getAll contacts cb)))]
    (fn [local put-fn]
      (when (= (:active-tab @local) :settings)
        [view {:style {:flex-direction "column"
                       :padding-top    10
                       :padding-bottom 10}}
         [text {:style {:font-size     10
                        :color         "#888"
                        :font-weight   "100"
                        :margin-bottom 5
                        :text-align    "center"}}
          (str (count @entries) " entries "
               (.-length (:contacts @local)) " contacts"
               (when-let [barcode (:barcode @local)]
                 (str " - " barcode)))]

         [view {:style {:flex-direction "column"
                        :padding-top    10
                        :padding-bottom 10
                        :padding-left   10
                        :padding-right  10}}

          [view {:style {:padding-top    10
                         :padding-bottom 10
                         :padding-left   10
                         :padding-right  10}}
           [btn {:name     "bolt"
                 :style    {:background-color :red
                            :width            160}
                 :on-press #(put-fn [:state/reset])}
            [text {:style {:color       :white
                           :text-align  "center"
                           :font-size   12
                           :font-weight "bold"}}
             "reset"]]]

          [divider]

          [view {:style {:padding-top    10
                         :padding-bottom 10
                         :padding-left   10
                         :padding-right  10}}
           [btn {:name     "address-card-o"
                 :style    {:background-color "#999"
                            :width            160}
                 :on-press read-contacts}
            [text {:style {:color       :white
                           :text-align  "center"
                           :font-size   12
                           :font-weight "bold"}}
             "import"]]]

          [divider]

          [view {:style {:padding-top    10
                         :padding-bottom 10
                         :padding-left   10
                         :padding-right  10}}
           [btn {:name     "camera-retro"
                 :on-press #(swap! local update-in [:cam] not)}
            [text {:style {:color       :white
                           :text-align  "center"
                           :font-size   12
                           :font-weight "bold"}}
             (if (:cam @local) "hide cam" "ws")]]]

          [divider]

          [btn {:name     "refresh"
                :style    {:background-color "#99E"}
                :on-press #(put-fn [:sync/initiate])}
           [text {:style {:color       :white
                          :text-align  "center"
                          :font-size   12
                          :font-weight "bold"}}
            "sync"]]

          [divider]]

         [divider]

         [picker {:selected-value  (:map-style @local)
                  :on-value-change (fn [v idx]
                                     (let [style (keyword v)]
                                       (swap! local assoc-in [:map-style] style)))}
          (for [[k style] mapbox-style-url]
            ^{:key k}
            [picker-item {:label (name k) :value k}])]
         [scroll {}
          [view {:style {:flex-direction "row"
                         :width          "100%"}}
           [map-view {:showUserLocation true
                      :centerCoordinate [9.95 53.55]
                      ;:scrollEnabled    false
                      ;:rotateEnabled    false
                      ;:zoomEnabled      false
                      :styleURL         (get mapbox-style-url (:map-style @local))
                      :style            {:width         "auto"
                                         :flex          2
                                         :height        300
                                         :margin-bottom 10}
                      :zoomLevel        10}]]
          [text {:style {:color      :black
                         :text-align "center"
                         :font-size  8}}
           (str (with-out-str (pp/pprint (js->clj mapbox))))]]

         (when (:cam @local)
           [cam {:style         {:width  300
                                 :height 300}
                 :onBarCodeRead on-barcode-read}])

         [flat-list {:data        (:contacts @local)
                     :render-item render-item}]]))))
