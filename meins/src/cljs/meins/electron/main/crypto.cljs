(ns meins.electron.main.crypto
  (:require ["keytar" :as keytar :refer [getPassword setPassword]]
            [meins.electron.main.runtime :as rt]
            [meins.shared.encryption :as mse]
            [taoensso.timbre :refer [debug error info warn]]))

(def app-key
  (if (:repo-dir rt/runtime-info)
    "meins-dev"
    "meins"))

(defn save-key-pair [key-pair]
  (let [{:keys [publicKey secretKey]} key-pair]
    (setPassword app-key "publicKey" publicKey)
    (setPassword app-key "secretKey" secretKey)))

(defn get-secret-key []
  (getPassword app-key "secretKey"))

(defn get-public-key []
  (getPassword app-key "publicKey"))

(defn key-pair [state]
  (select-keys state [:publicKey :secretKey]))

(defn create-keypair [{:keys [cmp-state]}]
  (let [key-pair (mse/gen-key-pair-hex)]
    (save-key-pair key-pair)
    (swap! cmp-state merge key-pair)
    (info "created key pair, public key:" (:publicKey key-pair))
    {:emit-msg [:crypto/cfg (key-pair @cmp-state)]}))

(defn get-cfg [{:keys [current-state]}]
  {:emit-msg [:crypto/cfg (key-pair current-state)]})

(defn state-fn [put-fn]
  (let [state (atom {})]
    (-> (get-secret-key)
        (.then (fn [sk]
                 (swap! state assoc :secretKey sk)
                 (-> (get-public-key)
                     (.then (fn [pk]
                              (swap! state assoc :publicKey pk)
                              (put-fn [:crypto/cfg (key-pair @state)])))))))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:crypto/create-keys create-keypair
                 :crypto/get-cfg     get-cfg}})
