(ns meins.shared.encryption
  (:require ["crypto-js" :refer [AES algo enc util lib PBKDF2] :as crypto]
            [cljs.reader :as edn]
            [clojure.string :as s]
            ["tweetnacl" :refer [box randomBytes]]
            ["tweetnacl-util" :refer [decodeUTF8 encodeUTF8 encodeBase64 decodeBase64]]
            [clojure.string :as str]))

(def iterations 1024)

(def utf-8 (.-Utf8 enc))
(def hex (.-Hex enc))
(def word-array (.-WordArray lib))

(defn buffer-convert [from to s]
  (let [buffer (.from js/Buffer s from)]
    (.toString buffer to)))

(defn utf8-to-hex [s] (buffer-convert "utf-8" "hex" s))
(defn hex-to-utf8 [s] (buffer-convert "hex" "utf-8" s))

(defn hex->base64 [s] (buffer-convert "hex" "base64" s))
(defn base64->hex [s] (buffer-convert "base64" "hex" s))

(defn hex->array [s] (decodeBase64 (hex->base64 s)))
(defn array->hex [s] (base64->hex (encodeBase64 s)))

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
  (try
    (let [iv (.random word-array 128/8)
          opts (clj->js {:iv iv})
          [salt key-256] (key-from-pw secret)
          cipher (->> (.encrypt AES s key-256 opts)
                      (.toString)
                      (utf8-to-hex))]
      (str "v1." salt "." iv "." cipher))
    (catch :default e (js/console.error "encrypt" e))))

(defn decrypt-v1 [hex-cipher secret]
  (try
    (let [[_version salt iv hex-cipher] (s/split hex-cipher ".")
          salt (hex-to-words salt)
          iv (hex-to-words iv)
          opts (clj->js {:iv iv})
          key-256 (key-from-pw-salt secret salt)
          ciphertext (hex-to-utf8 hex-cipher)
          decrypted-bytes (.decrypt AES ciphertext key-256 opts)]
      (.toString decrypted-bytes utf-8))
    (catch :default e (js/console.error "decrypt" e))))

;; TweetNaCl.js
(defn new-nonce []
  (randomBytes (.-nonceLength box)))

(defn gen-key-pair []
  (js->clj (.keyPair box) :keywordize-keys true))

(defn encrypt-asymm
  "Encrypt message via x25519-xsalsa20-poly1305 using the public key of the
   recipient and the local private key."
  [message their-public-key my-secret-key]
  (try
    (let [nonce (new-nonce)
          messageUint8 (decodeUTF8 message)
          encrypted (box messageUint8 nonce their-public-key my-secret-key)
          ciphertext (array->hex encrypted)
          nonce-base64 (array->hex nonce)]
      (str "v2." nonce-base64 "." ciphertext))
    (catch :default e (js/console.error "encrypt-asymm" e))))

(defn decrypt-asymm
  "Decrypt x25519-xsalsa20-poly1305 encrypted message using the public key
   of the encryptor and the local private key."
  [message their-public-key my-secret-key]
  (try
    (let [[_version nonce-hex ciphertext] (str/split message ".")
          nonce (hex->array nonce-hex)
          encrypted (hex->array ciphertext)
          decrypted (.open box encrypted nonce their-public-key my-secret-key)]
      (encodeUTF8 decrypted))
    (catch :default e (js/console.error "decrypt-asymm" e))))

(defn decrypt
  "Decrypts ciphertext based on the version, which is encoded in the first characters
   of the ciphertext leading up to the first dot."
  [cipher secret]
  (try
    (case (first (s/split cipher "."))
      "v1" (edn/read-string (decrypt-v1 cipher secret))
      nil)
    (catch :default e (js/console.error "decrypt" e))))
