(ns meo.electron.main.imap
  "Component for encrypting and decrypting log files."
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync mkdirSync writeFile writeFileSync statSync]]
            [child_process :refer [spawn]]
            [meo.electron.main.utils.encryption :as mue]
            [imap :as imap]
            [clojure.data :as data]
            [buildmail :as BuildMail]
            [cljs.reader :as edn]
            [clojure.pprint :as pp]
            [clojure.string :as s]))

(def data-path (:data-path rt/runtime-info))
(def img-path (:img-path rt/runtime-info))
(def repo-dir (:repo-dir rt/runtime-info))
(def cfg-path (str data-path "/imap.edn"))

(defn pp-str [x]
  (binding [pp/*print-right-margin* 100]
    (with-out-str (pp/pprint x))))

(defn imap-cfg []
  (when (existsSync cfg-path)
    (edn/read-string (readFileSync cfg-path "utf-8"))))

(defn imap-open [mailbox-name open-mb-cb]
  (when-let [cfg (imap-cfg)]
    (try
      (let [conn (imap. (clj->js (:server cfg)))]
        (.once conn "ready" #(.openBox conn mailbox-name false (partial open-mb-cb conn)))
        (.once conn "error" #(error "IMAP connection" %))
        (.once conn "end" #(info "IMAP connection ended"))
        (info "imap-open" mailbox-name)
        (.connect conn)
        (js/setTimeout #(.end conn) 60000))
      (catch :default e (error e))))
  {})

(defn buf-from-base64 [b64]
  (.from js/Buffer b64 "base64"))

(defn read-image [mailbox uid partID filename put-fn]
  (let [body-cb (fn [buffer seqn stream stream-info]
                  (let [end-cb (fn []
                                 (let [base-64-img (apply str @buffer)
                                       buf (buf-from-base64 base-64-img)
                                       full-path (str img-path "/" filename)
                                       write-cb (fn [err]
                                                  (if err
                                                    (error err)
                                                    (do (info "wrote" full-path)
                                                        (put-fn [:import/gen-thumbs
                                                                 {:filename  filename
                                                                  :full-path full-path}]))))]
                                   (info "image" filename (count base-64-img))
                                   (writeFile full-path buf "binary" write-cb)))]
                    (info "image body stream-info" (js->clj stream-info))
                    (.on stream "data" #(let [s (.toString % "UTF8")]
                                          (when (= partID (.-which stream-info))
                                            (swap! buffer conj s))
                                          (debug "image body data seqno" seqn "- size" (count s))))
                    (.once stream "end" end-cb)))
        msg-cb (fn [msg seqn]
                 (let [buffer (atom [])]
                   (.on msg "body" (partial body-cb buffer seqn))
                   (.once msg "end" #(debug "image msg end" seqn))))
        mb-cb (fn [conn err box]
                (try
                  (let [s (clj->js ["UNDELETED" ["UID" uid]])
                        cb (fn [err res]
                             (let [
                                   f (.fetch conn res (clj->js {:bodies [partID]
                                                                :struct true}))
                                   cb (fn []
                                        (info "finished reading" filename)
                                        (.end conn))]
                               (info "search fetch" res)
                               (.on f "message" msg-cb)
                               (.once f "error" #(error "Fetch error" %))
                               (.once f "end" cb)))]
                    (info "search" mailbox s)
                    (.search conn s cb))
                  (catch :default e (error e))))]
    (imap-open mailbox mb-cb)))

(defn read-mailbox [[k mb-cfg] put-fn]
  (let [{:keys [secret mailbox body-part]} mb-cfg
        path [:sync :read k :last-read]
        body-cb (fn [buffer seqn stream stream-info]
                  (let [end-cb (fn []
                                 (let [hex-body (mue/extract-body (apply str @buffer))
                                       cfg (assoc-in (imap-cfg) path seqn)
                                       s (pp-str cfg)]
                                   (info "end-cb buffer" seqn "- size" (count hex-body))
                                   (debug hex-body)
                                   (when-let [decrypted (mue/decrypt-aes-hex hex-body secret)]
                                     (let [msg-type (first decrypted)
                                           {:keys [msg-payload msg-meta]} (second decrypted)
                                           msg-meta (merge msg-meta {:window-id :broadcast})
                                           msg (with-meta [msg-type msg-payload] msg-meta)]
                                       (info "IMAP body end" seqn "- decrypted size" (count (str decrypted)))
                                       (info decrypted)
                                       (put-fn msg)))
                                   (info "body-cb last-read" seqn)
                                   (writeFileSync cfg-path s)))]
                    (info "IMAP body stream-info" (js->clj stream-info))
                    (.on stream "data" #(let [s (.toString % "UTF8")]
                                          (when (= body-part (.-which stream-info))
                                            (swap! buffer conj s))
                                          (info "IMAP body data seqno" seqn "- size" (.-size stream-info))))
                    (.once stream "end" end-cb)))
        msg-cb (fn [msg seqn]
                 (let [buffer (atom [])]
                   (.once msg "attributes" (fn [attrs]
                                             (let [uid (.-uid attrs)
                                                   struct (js->clj (.-struct attrs) :keywordize-keys true)
                                                   attachment (-> struct last last)]
                                               (pp/pprint attachment)
                                               (when (= "image" (:type attachment))
                                                 (let [filename (-> attachment
                                                                    :disposition
                                                                    :params
                                                                    :filename
                                                                    (s/replace "=?utf-8?Q?" "")
                                                                    (s/replace "?=" "")
                                                                    (s/replace "=5F" "_"))
                                                       partID (:partID attachment)]
                                                   (read-image mailbox uid partID filename put-fn)
                                                   (info "found attachment" filename uid partID))))))
                   (.on msg "body" (partial body-cb buffer seqn))
                   (.once msg "end" #(debug "IMAP msg end" seqn))))
        mb-cb (fn [conn err box]
                (try
                  (let [last-read (get-in (imap-cfg) path 0)
                        uid (str (inc last-read) ":*")
                        s (clj->js ["UNDELETED" ["UID" uid]])
                        cb (fn [err res]
                             (let [parsed-res (js->clj res)]
                               (when (and (seq parsed-res) (> (last parsed-res) last-read))
                                 (let [last-read (last parsed-res)
                                       f (.fetch conn res (clj->js {:bodies [body-part]
                                                                    :struct true}))
                                       cb (fn []
                                            (info "mb-cb fetch end, last-read" last-read)
                                            (.end conn))]
                                   (info "search fetch" res)
                                   (.on f "message" msg-cb)
                                   (.once f "error" #(error "Fetch error" %))
                                   (.once f "end" cb)))))]
                    (info "search" mailbox s)
                    (.search conn s cb))
                  (catch :default e (error e))))]
    (imap-open mailbox mb-cb)))

(defn read-email [{:keys [put-fn]}]
  (doseq [mb-tuple (:read (:sync (imap-cfg)))]
    (read-mailbox mb-tuple put-fn))
  {})

(defn write-email [{:keys [msg-payload msg-meta]}]
  (when-let [mb-cfg (:write (:sync (imap-cfg)))]
    (let [mailbox (:mailbox mb-cfg)
          cb (fn [conn _err _box]
               ;(.getBoxes mb (fn [err boxes] (.log js/console boxes)))
               (try
                 (let [secret (:secret mb-cfg)
                       ; actual meta-data too large, makes the encryption waste battery
                       msg-meta {}
                       serializable [:entry/sync {:msg-payload msg-payload
                                                  :msg-meta    msg-meta}]
                       cipher-hex (mue/encrypt-aes-hex (pr-str serializable) secret)
                       append-cb (fn [err]
                                   (if err
                                     (error "IMAP write" err)
                                     (info "IMAP wrote message"))
                                   (info "closing WRITE connection")
                                   (.end conn))
                       cb (fn [_err rfc-2822]
                            (debug "RFC2822\n" rfc-2822)
                            (.append conn rfc-2822 append-cb))]
                   (-> (BuildMail. "text/plain")
                       (.setContent cipher-hex)
                       (.setHeader "subject" (str (:timestamp msg-payload) " " (:vclock msg-payload)))
                       (.build cb)))
                 (catch :default e (error e))))]
      (imap-open mailbox cb)))
  {})

(defn read-mailboxes [{:keys [put-fn msg-payload]}]
  (info "read-mailboxes" msg-payload)
  (when-let [cfg msg-payload]
    (try
      (let [cb (fn [conn _err mb]
                 (try
                   (.getBoxes conn (fn [err boxes]
                                     (.log js/console boxes)
                                     (put-fn [:imap/status {:status :read-mailboxes}])
                                     (info "read mailboxes")))
                   (catch :default e (put-fn [:imap/status {:status :error :detail (str e)}]))))
            conn (imap. (clj->js (:server cfg)))]
        (.once conn "ready" #(.openBox conn "INBOX" false (partial cb conn)))
        (.once conn "error" #(put-fn [:imap/status {:status :error :detail (str %)}]))
        (.once conn "end" #(info "IMAP connection ended"))
        (.connect conn)
        (js/setTimeout #(.end conn) 60000))
      (catch :default e (put-fn [:imap/status {:status :error :detail (str e)}]))))
  {})

(defn start-sync [{:keys [current-state put-fn]}]
  (info "starting IMAP sync")
  {:emit-msg [:cmd/schedule-new {:timeout (* 15 1000)
                                 :id      :imap-schedule
                                 :message [:sync/read-imap]
                                 :initial true
                                 :repeat  true}]})

(defn get-cfg [{:keys []}]
  (info "get-cfg")
  {:emit-msg [:imap/cfg (imap-cfg)]})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    (fn [_put-fn] {:state (atom {})})
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:sync/imap       write-email
                 :imap/get-status read-mailboxes
                 :imap/get-cfg    get-cfg
                 :sync/start-imap start-sync
                 :sync/read-imap  read-email}})
