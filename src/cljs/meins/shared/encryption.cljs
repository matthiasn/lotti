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
    (str "v1." salt "." iv "." cipher)))

(defn decrypt-v1 [hex-cipher secret]
  (try (let [[_version salt iv hex-cipher] (s/split hex-cipher ".")
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

;; TweetNaCl.js
(defn new-nonce []
  (randomBytes (.-nonceLength box)))

(defn gen-key-pair []
  (js->clj (.keyPair box) :keywordize-keys true))

(defn encrypt-asymm
  "Encrypt message via x25519-xsalsa20-poly1305 using the public key of the
   recipient and the local private key."
  [message their-public-key my-secret-key]
  (let [nonce (new-nonce)
        messageUint8 (decodeUTF8 message)
        encrypted (box messageUint8 nonce their-public-key my-secret-key)
        ciphertext (encodeBase64 encrypted)
        nonce-base64 (encodeBase64 nonce)]
    (str "v2." nonce-base64 "." ciphertext)))

(defn decrypt-asymm
  "Decrypt x25519-xsalsa20-poly1305 encrypted message using the public key
   of the encryptor and the local private key."
  [message their-public-key my-secret-key]
  (let [[_version nonce-base64 ciphertext] (str/split message ".")
        nonce (decodeBase64 nonce-base64)
        encrypted (decodeBase64 ciphertext)
        decrypted (.open box encrypted nonce their-public-key my-secret-key)]
    (encodeUTF8 decrypted)))

(defn test-asym-encrypt [s]
  (js/console.log "Generating Key Pairs")
  (let [key-pair-a (time (gen-key-pair))
        key-pair-b (time (gen-key-pair))
        their-public-key (:publicKey key-pair-b)
        my-secret-key (:secretKey key-pair-a)
        cipher (time (encrypt-asymm s their-public-key my-secret-key))
        _ (js/console.warn ">>> ciphertext: " cipher)
        deciphered (time (decrypt-asymm cipher their-public-key my-secret-key))]
    (js/console.warn ">>> deciphered: " deciphered)))

(defn decrypt
  "Decrypts ciphertext based on the version, which is encoded in the first characters
   of the ciphertext leading up to the first dot. v1 and no version substring are the
   same, except for the added version in v1"
  [hex-cipher secret]
  (try
    (case (first (s/split hex-cipher "."))
      "v1" (decrypt-v1 hex-cipher secret)
      (decrypt-v1 hex-cipher secret))
    (catch :default e (js/console.error "decrypt" e))))
