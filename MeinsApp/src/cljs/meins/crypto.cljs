(ns meins.crypto
  (:require ["@matthiasn/react-native-randombytes" :refer [randomBytesSync]]
            [meins.shared.encryption :as mse]))

(defn random-bytes [uint8arr n]
  (let [base64 (randomBytesSync n)
        rand-buf (js/Buffer. base64 "base64")]
    (.set uint8arr rand-buf)))

(mse/set-prng random-bytes)
