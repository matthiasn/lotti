(ns meo.electron.main.utils.encryption
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync]]
            [crypto-js :refer [AES enc util] :as crypto]
            [cljs.reader :as edn]
            [clojure.string :as s]))

(def utf-8 (.-Utf8 enc))
(def hex (.-Hex enc))

(def data-path (:data-path rt/runtime-info))
(def repo-dir (:repo-dir rt/runtime-info))

(defn read-secret []
  (let [secret-path (str (if repo-dir "./data" data-path) "/secret.txt")]
    (when (existsSync secret-path)
      (readFileSync secret-path "utf-8"))))

(defn buffer-convert [from to s]
  (let [buffer (.from js/Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8"  s))
(defn extract-body [s] (s/replace s "=\r\n" ""))

(defn encrypt-aes-hex [s secret]
  (->> (.encrypt AES s secret)
       (.toString)
       (utf8-to-hex)))

(defn decrypt-aes-hex [hex-cipher secret]
  (try (let [ciphertext (hex-to-utf8 hex-cipher)
             decrypted-bytes (.decrypt AES ciphertext secret)
             s (.toString decrypted-bytes utf-8)]
         (debug "decrypt-aes-hex" s)
         (edn/read-string s))
       (catch :default e (error "decrypt" e))))
