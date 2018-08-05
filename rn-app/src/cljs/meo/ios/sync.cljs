(ns meo.ios.sync
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]]
            [clojure.string :as s]
            [meo.ui.shared :as shared]
            [cljs.reader :as edn]
            [clojure.pprint :as pp]))

(def crypto-js (js/require "crypto-js"))
(def AES (aget crypto-js "AES"))
(def utf-8 (aget crypto-js "enc" "Utf8"))

(def Buffer (aget (js/require "buffer") "Buffer"))

(defn buffer-convert [from to s]
  (let [buffer (.from Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))

(def MailCore (.-default (js/require "react-native-mailcore")))

(defn extract-body [s]
  (-> (str s)
      (s/split "-")
      first
      (s/replace " " "")
      (s/replace "=\r\n" "")
      (s/replace "\r\n" "")
      (s/replace "\n" "")))

(defn decrypt-body [body secret]
  (try
    (let [cleaned (extract-body body)
          ciphertext (hex-to-utf8 cleaned)
          decrypted-bytes (.decrypt AES ciphertext secret)
          s (.toString decrypted-bytes utf-8)
          data (edn/read-string s)]
      data)
    (catch :default e (shared/alert (str "decrypt body " e)))))

(defn sync-fn [{:keys [msg-type msg-payload msg-meta current-state]}]
  (try
    (let [secrets (:secrets current-state)
          aes-secret (:secret secrets)

          ; actual meta-data too large, makes the encryption waste battery
          msg-meta {}
          serializable [msg-type {:msg-payload msg-payload
                                  :msg-meta    msg-meta}]
          data (pr-str serializable)
          ciphertext (.toString (.encrypt AES data aes-secret))
          hex-cipher (utf8-to-hex ciphertext)

          _ (decrypt-body hex-cipher aes-secret)

          photo-uri (-> msg-payload :media :image :uri)
          filename (:img_file msg-payload)
          mail (merge (:server secrets)
                      {:from     {:addressWithDisplayName "fred"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :to       {:addressWithDisplayName "uschi"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :subject  (str msg-type)
                       :textBody hex-cipher}
                      (when (and (= :entry/sync msg-type) filename)
                        {:attachmentUri photo-uri
                         :filename      filename}))]
      (-> (.saveImap MailCore (clj->js mail))
          (.then #(.log js/console (str (js->clj %))))
          (.catch #(.log js/console (str (js->clj %))))))
    (catch :default e (.error js/console (str e)))))

(defn read-fn [{:keys [msg-payload current-state]}]
  (try
    (let [secrets (:secrets current-state)
          aes-secret (:secret secrets)
          mail (merge (:server secrets)
                      {:uid 42})]
      #_
      (-> (.fetchImap MailCore (clj->js mail))
          (.then #(.log js/console (str (js->clj %))))
          (.catch #(.log js/console (str (js->clj %)))))

      (-> (.fetchImapByUid MailCore (clj->js mail))
          ;(.then #(shared/alert (str "FETCH_BY_UID" (js->clj %))))
          (.then #(shared/alert (with-out-str
                                  (pp/pprint
                                    (decrypt-body (get (js->clj %) "body") aes-secret)))))
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
   :handler-map {:entry/sync  sync-fn
                 :sync/read   read-fn
                 :secrets/set set-secrets}})