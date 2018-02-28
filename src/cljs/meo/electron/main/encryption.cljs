(ns meo.electron.main.encryption
  "Component for encrypting and decrypting log files."
  (:require [matthiasn.systems-toolbox.component :as st]
            [taoensso.timbre :refer-macros [info debug error warn]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync mkdirSync writeFileSync statSync]]
            [crypto-js :refer [AES enc]]
            [child_process :refer [spawn]]
            [cljs.tools.reader.edn :as edn]
            [webdav :as webdav]
            [moment]))

(defn copy-to-webdav [filename node-id]
  (let [{:keys [encrypted-path repo-dir data-path]} rt/runtime-info
        data-path (if repo-dir "./data" data-path)
        enc-path (str encrypted-path "/" filename)
        cred-path (str data-path "/webdav.edn")]
    (if (existsSync cred-path)
      (let [cred-file (readFileSync cred-path "utf-8")
            {:keys [server username password]} (edn/read-string cred-file)
            client (webdav. server username password)
            file-data (readFileSync enc-path "utf-8")
            dir (str "/meo/" node-id "/")
            filename (str dir filename)
            file-stats (statSync enc-path)
            filesize (str (/ (Math/round (/ (.-size file-stats) 10.24)) 100) "kB")]
        (-> (.createDirectory client dir)
            (.then #(info "created" dir))
            (.catch #(warn "could not create" dir %)))
        (-> (.putFileContents client filename file-data {:format "text"})
            (.then #(info "copied" filename "to" server filesize))
            (.catch #(error "could not copy" filename "to" server %))))
      (warn "No WebDAV credentials found - file upload ABORTED"))))

(defn read-secret []
  (let [{:keys [repo-dir data-path]} rt/runtime-info
        secret-path (str (if repo-dir "./data" data-path) "/secret.txt")]
    (when (existsSync secret-path)
      (readFileSync secret-path "utf-8"))))

(defn encrypt [{:keys [msg-payload]}]
  (let [start (st/now)
        {:keys [filename node-id]} msg-payload
        {:keys [daily-logs-path encrypted-path repo-dir]} rt/runtime-info
        secret (read-secret)
        daily-logs-path (if repo-dir "./data/daily-logs" daily-logs-path)]
    (if secret
      (let [content (readFileSync (str daily-logs-path "/" filename) "utf-8")
            ciphertext (.toString (.encrypt AES content secret))
            enc-path (str encrypted-path "/" filename)
            decrypted-bytes (.decrypt AES ciphertext secret)
            decrypted (.toString decrypted-bytes (.-Utf8 enc))
            dur (- (st/now) start)]
        (when-not (existsSync encrypted-path)
          (mkdirSync encrypted-path))
        (writeFileSync enc-path ciphertext)
        (copy-to-webdav filename node-id)
        (let [success (= content decrypted)]
          (if success
            (info "encrypted file" filename "in" dur "ms, SUCCESS")
            (error "encrypted file" filename "in" dur "ms, FAILED comparison"))))
      (warn "No secret found - ENCRYPTION ABORTED"))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:file/encrypt encrypt}})
