(ns meo.electron.main.encryption
  "Component for encrypting and decrypting log files."
  (:require [matthiasn.systems-toolbox.component :as st]
            [taoensso.timbre :as timbre :refer-macros [info debug error]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync mkdirSync writeFileSync]]
            [crypto-js :refer [AES enc]]
            [child_process :refer [spawn]]
            [moment]))

(defn encrypt
  "Encrypt"
  [{:keys [current-state msg-payload]}]
  (let [start (st/now)
        filename (:filename msg-payload)
        {:keys [daily-logs-path encrypted-path repo-dir data-path]} rt/runtime-info
        secret-path (str (if repo-dir "./data" data-path) "/secret.txt")
        secret (readFileSync secret-path "utf-8")
        daily-logs-path (if repo-dir "./data/daily-logs" daily-logs-path)
        content (readFileSync (str daily-logs-path "/" filename) "utf-8")
        ciphertext (.toString (.encrypt AES content secret))
        enc-path (str encrypted-path "/" filename)
        decrypted-bytes (.decrypt AES ciphertext secret)
        decrypted (.toString decrypted-bytes (.-Utf8 enc))
        dur (- (st/now) start)]
    (when-not (existsSync encrypted-path)
      (mkdirSync encrypted-path))
    (info encrypted-path)
    (writeFileSync enc-path ciphertext)
    (let [success (= content decrypted)]
      (if success
        (info "encrypted file" filename "in" dur "ms, SUCCESS")
        (error "encrypted file" filename "in" dur "ms, FAILED comparison")))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:file/encrypt encrypt}})
