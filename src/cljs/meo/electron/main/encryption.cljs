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

(def utf-8 (.-Utf8 enc))

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

(defn encrypt [{:keys [msg-payload current-state]}]
  (let [start (st/now)
        new-state (assoc-in current-state [:last] start)
        {:keys [filename node-id]} msg-payload
        {:keys [daily-logs-path encrypted-path repo-dir]} rt/runtime-info
        secret (read-secret)
        daily-logs-path (if repo-dir "./data/daily-logs" daily-logs-path)]
    (if (> (- (st/now) (:last current-state 0)) 10000)
      (if secret
        (let [content (readFileSync (str daily-logs-path "/" filename) "utf-8")
              ciphertext (.toString (.encrypt AES content secret))
              enc-path (str encrypted-path "/" filename)
              bytes (.decrypt AES ciphertext secret)
              decrypted (.toString bytes utf-8)
              dur (- (st/now) start)]
          (when-not (existsSync encrypted-path)
            (mkdirSync encrypted-path))
          (writeFileSync enc-path ciphertext)
          (copy-to-webdav filename node-id)
          (let [success (= content decrypted)]
            (if success
              (info "encrypted file" filename "in" dur "ms, SUCCESS")
              (error "encrypted file" filename "in" dur "ms, FAILED comparison")))
          {:new-state new-state})
        (warn "No secret found - ENCRYPTION ABORTED"))
      {})))

(defn scan-inbox [{:keys [put-fn]}]
  (let [secret (read-secret)
        {:keys [repo-dir data-path]} rt/runtime-info
        data-path (if repo-dir "./data" data-path)
        cred-path (str data-path "/webdav.edn")
        cred-file (readFileSync cred-path "utf-8")
        {:keys [server username password]} (edn/read-string cred-file)
        client (webdav. server username password)
        tmp-path "/tmp/meo/inbox"]
    (info "scan-inbox")
    (when-not (existsSync tmp-path)
      (mkdirSync tmp-path))
    (-> (.getDirectoryContents client "/meo/inbox")
        (.then (fn [contents]
                 (let [contents (js->clj contents :keywordize-keys true)]
                   (doseq [file contents]
                     (let [{:keys [filename basename]} file]
                       (when (= (:type file) "file")
                         (-> (.getFileContents client filename (clj->js {:format "text"}))
                             (.then (fn [ciphertext]
                                      (let [bytes (.decrypt AES ciphertext secret)
                                            decrypted (.toString bytes utf-8)
                                            parsed (edn/read-string decrypted)
                                            move-to (str "/meo/processed/" basename)]
                                        (info filename "parsed")
                                        (-> (.moveFile client filename move-to)
                                            (.catch #(error %)))
                                        (put-fn [:entry/update parsed]))))
                             (.catch #(error %)))))))))
        (.catch #(warn %)))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:sync/scan-inbox scan-inbox
                 :file/encrypt    encrypt}})
