(ns meo.ios.sync
  (:require [meo.ui.shared :as sh]))

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))

(def Buffer (aget (js/require "buffer") "Buffer"))

(defn buffer-convert [from to s]
  (let [buffer (.from Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))

(def MailCore (.-default (js/require "react-native-mailcore")))

(defn write-to-imap [secrets entry msg-meta _put-fn]
  (try
    (let [aes-secret (:secret secrets)
          serializable [:entry/sync {:msg-payload entry
                                     :msg-meta    msg-meta}]
          data (pr-str serializable)
          ciphertext (.toString (.encrypt aes data aes-secret))
          photo-uri (-> entry :media :image :uri)
          filename (:img_file entry)
          mail (merge (:server secrets)
                      {:from     {:addressWithDisplayName "fred"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :to       {:addressWithDisplayName "uschi"
                                  :mailbox                "meo@nehlsen-edv.de"}
                       :subject  "hello uschi"
                       :htmlBody (utf8-to-hex ciphertext)}
                      (when filename
                        {:attachmentUri photo-uri
                         :filename      filename}))]
      (-> (.sendMail MailCore (clj->js mail))
          (.then #(.log js/console (str (js->clj %))))
          (.catch #(.log js/console (str (js->clj %))))))
    (catch :default e (sh/alert (str e)))))
