(ns meins.electron.main.crypto
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            ["keytar" :as keytar :refer [setPassword getPassword]]
            [meins.shared.encryption :as mse]))

(defn save-key-pair [key-pair]
  (let [{:keys [publicKey secretKey]} key-pair]
    (setPassword "meins" "publicKey" publicKey)
    (setPassword "meins" "secretKey" secretKey)))

(defn get-secret-key []
  (getPassword "meins" "secretKey"))

(defn create-keypair [{:keys []}]
  (let [key-pair (mse/gen-key-pair-hex)]
    (save-key-pair key-pair)
    (info "created key pair, public key:" (:publicKey key-pair))
    {}))

(defn state-fn [put-fn]
  (let [state (atom {})]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:crypto/create-keys create-keypair}})
