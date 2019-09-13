(ns meins.ui.elements.qr
  (:require [meins.ui.shared :refer [touchable-opacity set-clipboard]]
            ["react-native-qrcode-svg" :as qr]
            [re-frame.core :refer [subscribe]]
            [meins.util.keychain :as kc]
            [reagent.core :as r]))

(def qr-svg (r/adapt-react-class (aget qr "default")))

(defn qr-code [public-key]
  (let [instance-id (subscribe [:instance-id])]
    (fn qr-code-render [public-key]
      (when public-key
        (let [qr-value (pr-str {:public-key public-key
                                :node-id    @instance-id})]
          [touchable-opacity {:on-press #(set-clipboard qr-value)
                              :style    {:background-color "white"
                                         :padding          20
                                         :align-items      "center"}}
           [qr-svg {:value qr-value
                    :size  300}]])))))
