(ns meo.ios.sync
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]]
            [clojure.string :as s]))

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))

(def Buffer (aget (js/require "buffer") "Buffer"))

(defn buffer-convert [from to s]
  (let [buffer (.from Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))

(def MailCore (.-default (js/require "react-native-mailcore")))

(defn sync-fn [{:keys [msg-type msg-payload msg-meta current-state]}]
  (try
    (let [secrets (:secrets current-state)
          aes-secret (:secret secrets)

          ; actual meta-data too large, makes the encryption waste battery
          msg-meta {}
          serializable [msg-type {:msg-payload msg-payload
                                  :msg-meta    msg-meta}]
          data (pr-str serializable)
          ciphertext (.toString (.encrypt aes data aes-secret))
          photo-uri (-> msg-payload :media :image :uri)
          filename (:img_file msg-payload)
          mail (merge (:server secrets)
                      {:from     {:addressWithDisplayName "fred"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :to       {:addressWithDisplayName "uschi"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :subject  (str msg-type)
                       :textBody (utf8-to-hex ciphertext)}
                      (when (and (= :entry/sync msg-type) filename)
                        {:attachmentUri photo-uri
                         :filename      filename}))]
      (-> (.saveImap MailCore (clj->js mail))
          (.then #(.log js/console (str (js->clj %))))
          (.catch #(.log js/console (str (js->clj %))))))
    (catch :default e (.error js/console (str e)))))

(defn set-secrets [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:secrets] msg-payload)]
    (go (<! (as/set-item :secrets msg-payload)))
    {:new-state new-state}))

(defn state-fn [put-fn]
  (let [state (atom {})]
    (go
      (try
        (let [secrets (second (<! (as/get-item :secrets)))]
          (when secrets
            (swap! state assoc-in [:secrets] secrets)))
        (catch js/Object e
          (put-fn [:debug/error {:msg e}]))))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/sync        sync-fn
                 :firehose/cmp-recv sync-fn
                 :firehose/cmp-put  sync-fn
                 :secrets/set       set-secrets}})