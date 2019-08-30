(ns meins.ui.elements.qr
  (:require [meins.ui.shared :refer [touchable-opacity set-clipboard]]
            ["react-native-qrcode-svg" :as qr]
            [meins.util.keychain :as kc]
            [reagent.core :as r]))

(def qr-svg (r/adapt-react-class (aget qr "default")))

(defn qr-code []
  (let [kp (r/atom {})]
    (fn qr-code-render []
      (kc/get-keypair (fn [from-kc] (reset! kp from-kc)))
      (when (:publicKey @kp)
        (let [qr-value (pr-str {:public-key (:publicKey @kp)
                                :node-id    "foo0"})]
          [touchable-opacity {:on-press #(set-clipboard qr-value)
                              :style    {:background-color "white"
                                         :padding          20
                                         :align-items      "center"}}
           [qr-svg {:value qr-value
                    :size  300}]])))))
