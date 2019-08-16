(ns meins.shared.encryption
  (:require [crypto-js :refer [AES algo enc util lib PBKDF2] :as crypto]
            [cljs.reader :as edn]
            [clojure.string :as s]))

(def iterations 1024)

(def utf-8 (.-Utf8 enc))
(def hex (.-Hex enc))
(def word-array (.-WordArray lib))

(defn buffer-convert [from to s]
  (let [buffer (.from js/Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))
(defn words-to-hex [w] (.stringify hex w))
(defn hex-to-words [w] (.parse hex w))

(defn key-from-pw-salt
  [password salt]
  (let [opts (clj->js {:keySize    256/32
                       :hasher     (.-SHA256 algo)
                       :iterations iterations})
        key-256 (PBKDF2 password salt opts)]
    key-256))

(defn key-from-pw
  "Arbitrarily expensive password based key derivation function.
   The more expensive this function, the harder dictionary attacks
   will be."
  [password]
  (let [salt (.random word-array 128/8)
        key-256 (key-from-pw-salt password salt)
        salt-hex (words-to-hex salt)]
    [salt-hex key-256]))

(defn encrypt
  "Encryption function that uses a unique key for each cipher."
  [s secret]
  (let [iv (.random word-array 128/8)
        opts (clj->js {:iv iv})
        [salt key-256] (key-from-pw secret)
        cipher (->> (.encrypt AES s key-256 opts)
                    (.toString)
                    (utf8-to-hex))]
    (str salt "." iv "." cipher)))

(defn decrypt [hex-cipher secret]
  (try (let [[salt iv hex-cipher] (s/split hex-cipher ".")
             salt (hex-to-words salt)
             iv (hex-to-words iv)
             opts (clj->js {:iv iv})
             key-256 (key-from-pw-salt secret salt)
             ciphertext (hex-to-utf8 hex-cipher)
             decrypted-bytes (.decrypt AES ciphertext key-256 opts)
             s (.toString decrypted-bytes utf-8)
             data (edn/read-string s)]
         data)
       (catch :default e (js/console.error "decrypt" e))))
