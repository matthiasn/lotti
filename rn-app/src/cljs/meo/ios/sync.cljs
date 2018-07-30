(ns meo.ios.sync
  (:require [matthiasn.systems-toolbox.component :as st]
            [meo.helpers :as h]
            [meo.ui.shared :as sh]))

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))
(def webdav-fs (js/require "webdav-fs"))
(def rn-fs (js/require "react-native-fs"))
(def docs-path (aget rn-fs "DocumentDirectoryPath"))
(def img-path (str docs-path "/images"))
(def Buffer (aget (js/require "buffer") "Buffer"))

(defn write-img-to-webdav [secrets filename base64 put-fn]
  (try
    (let [{:keys [server username password aes-secret directory]} secrets
          ciphertext (.toString (.encrypt aes base64 aes-secret))
          client (webdav-fs. server username password)
          dir (str directory "/images")
          filename (str dir "/" filename)
          mk-dir (aget client "mkdir")
          write (aget client "writeFile")
          write-err (fn [err]
                      (if err
                        (put-fn [:log/error
                                 (str "error writing " filename " on " server " " err)])
                        (put-fn [:log/info (str "wrote " filename)])))
          mkdir-err (fn [err]
                      (if err
                        (put-fn [:log/warn (str "could not create " dir err)])
                        (put-fn [:log/info (str "created " dir)])))]
      (mk-dir dir mkdir-err)
      (write filename ciphertext write-err)
      ;(write filename base64 write-err)
      (put-fn [:log/info (str "written: " filename)]))
    (catch js/Object e (put-fn [:log/error (str e)]))))

(defn copy-img-asset [entry secrets put-fn]
  (when-let [img (:image (:media entry))]
    (let [ts (:timestamp entry)
          filename (:img-file entry)
          dest (str img-path "/" filename)
          uri (:uri img)]
      (-> (.readdir rn-fs docs-path)
          (.then #(put-fn [:log/info (str docs-path " " %)])))
      (-> (.mkdir rn-fs img-path)
          (.then #(put-fn [:log/info %])))
      (-> (.readdir rn-fs docs-path)
          (.then #(put-fn [:log/info %])))
      (-> (.copyAssetsFileIOS rn-fs uri dest 0 0 1.0 0.8 "contain")
          (.then (fn [r]
                   (put-fn [:log/info (str "copied: " r)])
                   (-> (.stat rn-fs dest)
                       (.then (fn [r] (put-fn [:log/info r]))))
                   (-> (.readdir rn-fs img-path)
                       (.then #(put-fn [:log/info %])))
                   (-> (.readFile rn-fs dest "base64")
                       (.then (fn [base64]
                                (write-img-to-webdav secrets filename base64 put-fn)
                                (put-fn [:log/info (subs base64 0 100)]))))))
          (.catch (fn [e] (put-fn [:log/error (str "error: " dest " " e)])))))))

(defn write-to-webdav [secrets entry put-fn]
  (try
    (let [{:keys [server username password aes-secret directory]} secrets
          entry (update-in entry [:tags] conj "#import")
          data (pr-str entry)
          ciphertext (.toString (.encrypt aes data aes-secret))
          client (webdav-fs. server username password)
          dir (str directory "/inbox")
          filename (str dir "/" (st/now) "-" (:timestamp entry) ".edn")
          mk-dir (aget client "mkdir")
          write (aget client "writeFile")
          write-err (fn [err]
                      (if err
                        (put-fn [:log/error
                                 (str "error writing " filename " on " server " " err)])
                        (put-fn [:log/info (str "wrote " filename)])))
          mkdir-err (fn [err]
                      (if err
                        (put-fn [:log/warn (str "could not create " dir err)])
                        (put-fn [:log/info (str "created " dir)])))]
      (mk-dir dir mkdir-err)
      (write filename ciphertext write-err)
      (copy-img-asset entry secrets put-fn)
      (put-fn [:log/info (str "written: " filename)]))
    (catch js/Object e (put-fn [:log/error (str e)]))))


(defn buffer-convert [from to s]
  (let [buffer (.from Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))

(def MailCore (.-default (js/require "react-native-mailcore")))

(defn write-to-imap [secrets entry _put-fn]
  (try
    (let [aes-secret (:secret secrets)
          data (pr-str entry)
          ciphertext (.toString (.encrypt aes data aes-secret))
          photo-uri (-> entry :media :image :uri)
          filename (-> entry :media :image :filename)
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
