(ns meins.shared.encryption
  (:require ["tweetnacl" :refer [box randomBytes setPRNG]]
            ["tweetnacl-util" :refer [decodeBase64 decodeUTF8 encodeBase64 encodeUTF8]]
            [cljs.reader :as edn]
            [clojure.string :as str]
            [taoensso.timbre :refer [error info]]))

(defn buffer-convert [from to s]
  (let [buffer (.from js/Buffer s from)]
    (.toString buffer to)))

(defn hex->base64 [s] (buffer-convert "hex" "base64" s))
(defn base64->hex [s] (buffer-convert "base64" "hex" s))

(defn hex->array [s] (decodeBase64 (hex->base64 s)))
(defn array->hex [s] (base64->hex (encodeBase64 s)))

;; TweetNaCl.js
(defn new-nonce []
  (randomBytes (.-nonceLength box)))

(defn gen-key-pair []
  (js->clj (.keyPair box) :keywordize-keys true))

(defn gen-key-pair-hex []
  (-> (gen-key-pair)
      (update :publicKey array->hex)
      (update :secretKey array->hex)))

(defn encrypt-asymm
  "Encrypt message via x25519-xsalsa20-poly1305 using the public key of the
   recipient and the local private key."
  [message their-public-key our-secret-key]
  (try
    (let [their-public-key (hex->array their-public-key)
          our-secret-key (hex->array our-secret-key)
          nonce (new-nonce)
          messageUint8 (decodeUTF8 message)
          encrypted (box messageUint8 nonce their-public-key our-secret-key)
          ciphertext (array->hex encrypted)
          nonce-base64 (array->hex nonce)]
      (str "v2." nonce-base64 "." ciphertext))
    (catch :default e (js/console.error "encrypt-asymm" e))))

(defn decrypt-asymm
  "Decrypt x25519-xsalsa20-poly1305 encrypted message using the public key
   of the encryptor and the local private key."
  [message their-public-key our-secret-key]
  (info "decrypt-asymm message" message)
  (info "decrypt-asymm their-public-key" their-public-key)
  (info "decrypt-asymm our-secret-key" (subs our-secret-key 5))
  (try
    (let [[_version nonce-hex ciphertext] (str/split message ".")
          nonce (hex->array nonce-hex)
          encrypted (hex->array ciphertext)
          their-public-key (hex->array their-public-key)
          our-secret-key (hex->array our-secret-key)
          decrypted (.open box encrypted nonce their-public-key our-secret-key)]
      (encodeUTF8 decrypted))
    (catch :default e (error "decrypt-asymm" e))))

(defn set-prng [f]
  (setPRNG f))

(defn decrypt
  "Decrypts ciphertext based on the version, which is encoded in the first characters
   of the ciphertext leading up to the first dot."
  [cipher their-public-key our-secret-key]
  (try
    (case (first (str/split cipher "."))
      "v2" (edn/read-string (decrypt-asymm cipher their-public-key our-secret-key))
      nil)
    (catch :default e (js/console.error "decrypt" e))))
