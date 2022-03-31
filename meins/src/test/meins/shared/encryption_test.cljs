(ns meins.shared.encryption-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.shared.encryption :as mse]
            [cljs.reader :as edn]))

(def test-entry
  {:mentions       #{}
   :tags           #{"#elliptic-curve"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry-type     :story
   :planned-dur    1500
   :comment-for    1465059139281
   :completed-time 0
   :timestamp      1465059173965
   :md             "Encryption test #elliptic-curve"})

(def test-hex "b67a5aba95e0f406d0e6d9c39338df92fa14414508788831bac0c39fd6bfc472")
(def test-utf8 "He wes Leovenaðes sone -- liðe him be Drihten.")

(deftest hex->base64->hex-test
  (let [base64 (mse/hex->base64 test-hex)]
    (testing "output is of expected type"
      (is (= js/String (type base64))))
    (testing "conversion back to hex results in identical string"
      (is (= test-hex (mse/base64->hex base64))))))

(deftest hex->array->hex-test
  (let [arr (mse/hex->array test-hex)]
    (testing "array is of expected type"
      (is (= js/Uint8Array (type arr))))
    (testing "conversion back to hex results in identical string"
      (is (= test-hex (mse/array->hex arr))))))

(deftest gen-key-pair-test
  (let [{:keys [publicKey secretKey]} (mse/gen-key-pair)]
    (testing "public key is of expected type and length"
      (is (= js/Uint8Array (type publicKey)))
      (is (= 32 (.-length publicKey))))
    (testing "secret key is of expected type and length"
      (is (= js/Uint8Array (type secretKey)))
      (is (= 32 (.-length secretKey))))))

(deftest asymmetric-encryption-roundtrip-test
  (let [key-pair-a (mse/gen-key-pair-hex)
        key-pair-b (mse/gen-key-pair-hex)
        their-public-key (:publicKey key-pair-b)
        our-secret-key (:secretKey key-pair-a)
        serialized (pr-str test-entry)
        cipher (mse/encrypt-asymm serialized their-public-key our-secret-key)
        deciphered (mse/decrypt-asymm cipher their-public-key our-secret-key)
        deserialized (edn/read-string deciphered)]
    (testing "encryption followed by decryption yields identical data structure"
      (is (= serialized deciphered))
      (is (= test-entry deserialized)))))
