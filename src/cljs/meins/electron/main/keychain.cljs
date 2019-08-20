(ns meins.electron.main.keychain
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            ["keytar" :as keytar :refer [setPassword]]))

(defn save-keypair [pair]
  (let [{:keys [publicKey secretKey]} pair]
    (setPassword "meins" "publicKey" publicKey)
    (setPassword "meins" "secretKey" secretKey)))
