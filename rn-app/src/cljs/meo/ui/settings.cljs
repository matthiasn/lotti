(ns meo.ui.settings
  (:require [reagent.core :as r]
            [meo.ui.shared :refer [view text touchable-highlight cam]]
            [re-frame.core :refer [subscribe]]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn settings-page [local put-fn]
  (let [entries (subscribe [:entries])
        on-barcode-read (fn [e]
                          (let [qr-code (js->clj e)
                                data (get qr-code "data")]
                            (swap! local assoc-in [:barcode] data)
                            (put-fn [:ws/connect {:host data}])
                            (swap! local assoc-in [:cam] false)))]
    (fn [local put-fn]
      (when (= (:active-tab @local) :settings)
        [view {:style {:flex-direction "column"
                       :padding-top    10
                       :padding-bottom 10
                       :padding-left   10
                       :padding-right  10}}
         [text {:style {:font-size     10
                        :color         "#888"
                        :font-weight   "100"
                        :margin-bottom 5
                        :text-align    "center"}}
          (str (count @entries) " entries")]

         [view {:style {:flex-direction "row"
                        :padding-top    10
                        :padding-bottom 10
                        :padding-left   10
                        :padding-right  10}}
          [touchable-highlight
           {:style    defaults
            :on-press #(put-fn [:state/reset])}
           [text {:style {:color       "white"
                          :text-align  "center"
                          :font-weight "bold"}}
            "reset"]]

          [touchable-highlight
           {:style    defaults
            :on-press #(swap! local update-in [:cam] not)}
           [text {:style {:color       "white"
                          :text-align  "center"
                          :font-weight "bold"}}
            (if (:cam @local) "hide cam" "ws")]]

          [touchable-highlight
           {:style    defaults
            :on-press #(put-fn [:sync/initiate])}
           [text {:style {:color       "white"
                          :text-align  "center"
                          :font-weight "bold"}}
            "sync"]]]

         (when-let [barcode (:barcode @local)]
           [text {:style {:font-size     12
                          :color         "#999"
                          :font-weight   "100"
                          :margin-bottom 5
                          :text-align    "center"}}
            (str barcode)])

         (when (:cam @local)
           [cam {:style         {:width  300
                                 :height 300}
                 :onBarCodeRead on-barcode-read}])

         #_(when (:cam @local)
             [view {:style {:flex   2
                            :height 300
                            :width  "100%"}}
              [cam {:style         {:width  300
                                    :height 300}
                    :onBarCodeRead on-barcode-read}]])
         ]))))
