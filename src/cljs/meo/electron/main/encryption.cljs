(ns meo.electron.main.encryption
  "Component for encrypting and decrypting log files."
  (:require [matthiasn.systems-toolbox.component :as st]
            [taoensso.timbre :refer-macros [info debug error warn]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync mkdirSync writeFileSync statSync]]
            [crypto-js :refer [AES enc]]
            [child_process :refer [spawn]]
            [webdav :as webdav]
            [imap :as imap]
            [moment]
            [js-base64 :refer [Base64]]
            [buildmail :as BuildMail]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.string :as str]
            [cljs.reader :as edn]))

(def utf-8 (.-Utf8 enc))

(def data-path (:data-path rt/runtime-info))
(def repo-dir (:repo-dir rt/runtime-info))

(defn copy-to-webdav [filename node-id]
  (let [{:keys [encrypted-path]} rt/runtime-info
        data-path (if repo-dir "./data" data-path)
        enc-path (str encrypted-path "/" filename)
        cred-path (str data-path "/webdav.edn")]
    (if (existsSync cred-path)
      (let [cred-file (readFileSync cred-path "utf-8")
            {:keys [server username password directory]} (edn/read-string cred-file)
            client (webdav. server username password)
            file-data (readFileSync enc-path "utf-8")
            dir (str directory "/" node-id "/")
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
  (let [secret-path (str (if repo-dir "./data" data-path) "/secret.txt")]
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
        data-path (if repo-dir "./data" data-path)
        cred-path (str data-path "/webdav.edn")]
    (when (existsSync cred-path)
      (let [cred-file (readFileSync cred-path "utf-8")
            {:keys [server username password directory]} (edn/read-string cred-file)
            inbox (str directory "/inbox")
            client (webdav. server username password)
            processed (str directory "/processed")]
        (info "scan-inbox")
        (-> (.getDirectoryContents client inbox)
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
                                                move-to (str processed "/" basename)]
                                            (info filename "parsed")
                                            (-> (.moveFile client filename move-to)
                                                (.catch #(error %)))
                                            (if (:deleted parsed)
                                              (put-fn [:entry/trash parsed])
                                              (put-fn [:entry/sync parsed])))))
                                 (.catch #(error %)))))))))
            (.catch #(warn %)))))
    {}))

(defn buf-from-base64 [b64]
  (.from js/Buffer b64 "base64"))

(defn scan-images [{:keys [put-fn]}]
  (let [secret (read-secret)
        img-path (:img-path rt/runtime-info)
        data-path (if repo-dir "./data" data-path)
        cred-path (str data-path "/webdav.edn")]
    (when (existsSync cred-path)
      (let [cred-file (readFileSync cred-path "utf-8")
            {:keys [server username password directory]} (edn/read-string cred-file)
            inbox (str directory "/images")
            client (webdav. server username password)
            processed (str directory "/processed")]
        (info "scan-images")
        (-> (.getDirectoryContents client inbox)
            (.then (fn [contents]
                     (let [contents (js->clj contents :keywordize-keys true)]
                       (doseq [file contents]
                         (let [{:keys [filename basename]} file
                               target (str img-path "/" basename)]
                           (when (= (:type file) "file")
                             (-> (.getFileContents client filename (clj->js {:format "text"}))
                                 (.then (fn [ciphertext]
                                          (let [bytes (.decrypt AES ciphertext secret)
                                                decrypted (.toString bytes utf-8)
                                                buf (buf-from-base64 decrypted)
                                                move-to (str processed "/" basename)]
                                            (info target "decrypted")
                                            (writeFileSync target buf)
                                            (-> (.moveFile client filename move-to)
                                                (.catch #(error %))))))
                                 (.catch #(error %)))))))))
            (.catch #(warn %)))))
    {}))

(defn imap-cfg []
  (let [cfg-path (str data-path "/imap.edn")]
    (info cfg-path)
    (when (existsSync cfg-path)
      (edn/read-string (readFileSync cfg-path "utf-8")))))

(defn imap-open [mailbox-name open-mb-cb]
  (when-let [cfg (imap-cfg)]
    (info "imap-open" mailbox-name cfg)
    (let [mb (imap. (clj->js (:server cfg)))]
      (.once mb "ready" #(.openBox mb mailbox-name false (partial open-mb-cb mb)))
      (.once mb "error" #(error "IMAP connection" %))
      (.once mb "end" #(info "IMAP connection ended"))
      (.connect mb)
      {})))

(defn parse-edn [seqn s]
  (try (edn/read-string s)
       (catch :default e (error "parsing EDN" seqn e "\n" s))))

(defn decrypt [seqn base-64-cipher]
  (debug "decrypt ciphertext\n" base-64-cipher)
  (try
    (let [secret (read-secret)
          ;ciphertext (.decode Base64 base-64-cipher)
          ;bytes (.decrypt AES ciphertext secret)
          bytes (.decrypt AES base-64-cipher secret)
          s (.toString bytes utf-8)]
      (info "decrypted" seqn s)
      (parse-edn seqn s))
    (catch :default e (error "decrypt" seqn e))))

(defn read-email [{:keys [put-fn]}]
  (info "read-email")
  (when-let [mb-name (first (:read (:sync (imap-cfg))))]
    (let [body-cb (fn [buffer seqn stream stream-info]
                    (let [end-cb (fn []
                                   (info "end-cb buffer" seqn @buffer)
                                   (when-let [decrypted (decrypt seqn (apply str @buffer))]
                                     (info "IMAP body end" seqn "- decrypted size" (count (str decrypted)))
                                     (put-fn [:entry/sync decrypted])))]
                      (info "IMAP body stream-info" (js->clj stream-info))
                      (.on stream "data" #(let [s (.toString % "UTF8")]
                                            (when (= "TEXT" (.-which stream-info))
                                              (swap! buffer conj s))
                                            (info "IMAP body data seqno" seqn "- size" (count s))))
                      (.once stream "end" end-cb)))
          msg-cb (fn [msg seqn]
                   (let [buffer (atom [])]
                     (.on msg "body" (partial body-cb buffer seqn))
                     (.once msg "end" #(info "IMAP msg end" seqn))))
          mb-cb (fn [mb err box]
                  (let [fetch (aget mb "seq" "fetch")
                        f (fetch "1:1000" (clj->js {:bodies ["TEXT"]
                                                    :struct true}))]
                    (.on f "message" msg-cb)
                    (.once f "error" #(error "Fetch error" %))
                    (.once f "end" (fn [] (info "IMAP msg fetch ended") (.end mb)))))]
      (imap-open mb-name mb-cb)
      {})))

(defn write-email [{:keys [msg-payload]}]
  (when-let [mb-name (:write (:sync (imap-cfg)))]
    (imap-open
      mb-name
      (fn [mb _err _box]
        (let [secret (read-secret)
              content (pr-str msg-payload)
              ciphertext (.toString (.encrypt AES content secret))
              ;base-64-enc (.encode Base64 ciphertext)
              cb (fn [_err rfc-2822]
                   (info "RFC2822\n" rfc-2822)
                   (.append mb rfc-2822 #(if % (error "IMAP write" %)
                                               (info "IMAP wrote message"))))]
          (-> (BuildMail. "text/plain")
              (.setContent ciphertext)
              (.setHeader "subject" (str (:timestamp msg-payload) " " (:vclock msg-payload)))
              (.build cb))))))
  {})

(defn state-fn [_put-fn]
  (let [state (atom {})]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:sync/scan-inbox  scan-inbox
                 :sync/scan-images scan-images
                 ;:file/encrypt     encrypt
                 :sync/imap        write-email
                 :sync/read-imap   read-email}})
