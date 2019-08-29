(ns meins.ui.elements.qr
  (:require [meins.ui.shared :refer [view]]
            ["react-native-qrcode-svg" :as qr]
            [reagent.core :as r]))

(def qr-svg (r/adapt-react-class (aget qr "default")))

(defn qr-code [qr-value]
  (when qr-value
    [view {:style {:background-color "white"
                   :padding          20
                   :align-items      "center"}}
     [qr-svg {:value qr-value
              :size  300}]]))
