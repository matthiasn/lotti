(ns meins.electron.main.utils.encryption
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            [meins.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync]]
            [crypto-js :refer [AES enc util lib PBKDF2] :as crypto]
            [cljs.reader :as edn]
            [clojure.string :as s]))

(def iterations 16384)

(def utf-8 (.-Utf8 enc))
(def hex (.-Hex enc))
(def word-array (.-WordArray lib))
(def data-path (:data-path rt/runtime-info))

(defn buffer-convert [from to s]
  (let [buffer (.from js/Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))
(defn words-to-hex [w] (.stringify hex w))
(defn hex-to-words [w] (.parse hex w))

(defn extract-body [s]
  (let [body (-> s
                 (s/replace "=\r\n" "")
                 (s/replace "\r\n" "")
                 (s/replace "\n" ""))]
    (if (s/includes? body "inline")
      (-> body
          (s/split "inline")
          second
          (s/split "--")
          first)
      body)))

(defn encrypt-aes-hex-1 [s secret]
  (->> (.encrypt AES s secret)
       (.toString)
       (utf8-to-hex)))

(defn key-from-pw-salt
  [password n salt]
  (let [opts (clj->js {:keySize    256/32
                       :iterations n})
        key-256 (PBKDF2 password salt opts)]
    key-256))

(defn key-from-pw
  "Arbitrarily expensive password based key derivation function.
   The more expensive this function, the harder dictionary attacks
   will be."
  [password n]
  (let [salt (.random word-array 128/8)
        key-256 (key-from-pw-salt password n salt)
        salt-hex (words-to-hex salt)]
    [salt-hex key-256]))

(defn encrypt-aes-hex-2
  "Encryption function that uses a unique key for each message
   encryption."
  [s secret]
  (let [iv (.random word-array 128/8)
        opts (clj->js {:iv iv})
        [salt key-256] (key-from-pw secret iterations)
        cipher (->> (.encrypt AES s key-256 opts)
                    (.toString)
                    (utf8-to-hex))]
    (str salt "." iv "." cipher)))

(defn decrypt-aes-hex-2 [hex-cipher secret]
  (try (let [[salt iv hex-cipher] (s/split hex-cipher ".")
             salt (hex-to-words salt)
             iv (hex-to-words iv)
             opts (clj->js {:iv iv})
             key-256 (key-from-pw-salt secret iterations salt)
             ciphertext (hex-to-utf8 hex-cipher)
             decrypted-bytes (.decrypt AES ciphertext key-256 opts)
             s (.toString decrypted-bytes utf-8)
             _ (debug "decrypt-aes-hex" s)
             data (edn/read-string s)]
         data)
       (catch :default e (error "decrypt" e))))

(defn encrypt-aes-hex [s secret]
  (info "encrypting" s)
  (let [cipher-hex (time (encrypt-aes-hex-1 s secret))
        cipher-hex2 (time (encrypt-aes-hex-2 s secret))
        decrypted (decrypt-aes-hex-2 cipher-hex2 secret)]
    (info :decrypted decrypted)
    cipher-hex))

(defn decrypt-aes-hex [hex-cipher secret]
  (try (let [ciphertext (hex-to-utf8 hex-cipher)
             decrypted-bytes (.decrypt AES ciphertext secret)
             s (.toString decrypted-bytes utf-8)
             _ (debug "decrypt-aes-hex" s)
             data (edn/read-string s)]
         (debug data)
         data)
       (catch :default e (error "decrypt" e))))
