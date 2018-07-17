(ns meo.electron.main.imap
  "Component for encrypting and decrypting log files."
  (:require [taoensso.timbre :refer-macros [info debug error warn]]
            [meo.electron.main.runtime :as rt]
            [fs :refer [existsSync readFileSync mkdirSync writeFileSync statSync]]
            [child_process :refer [spawn]]
            [meo.electron.main.utils.encryption :as mue]
            [imap :as imap]
            [clojure.data :as data]
            [buildmail :as BuildMail]
            [cljs.reader :as edn]))

(def data-path (:data-path rt/runtime-info))
(def repo-dir (:repo-dir rt/runtime-info))

(defn imap-cfg []
  (let [cfg-path (str data-path "/imap.edn")]
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

(defn read-email [{:keys [put-fn cmp-state]}]
  (when-let [mb-tuple (first (:read (:sync (imap-cfg))))]
    (let [mb (second mb-tuple)
          secret (:secret mb)
          body-cb (fn [buffer seqn stream stream-info]
                    (let [end-cb (fn []
                                   (let [hex-body (mue/extract-body (apply str @buffer))]
                                     (debug "end-cb buffer" seqn "- size" (count hex-body))
                                     (when-let [decrypted (mue/decrypt-aes-hex hex-body secret)]
                                       (info "IMAP body end" seqn "- decrypted size" (count (str decrypted)))
                                       (put-fn [:entry/sync decrypted]))))]
                      (info "IMAP body stream-info" (js->clj stream-info))
                      (.on stream "data" #(let [s (.toString % "UTF8")]
                                            (when (= "TEXT" (.-which stream-info))
                                              (swap! buffer conj s))
                                            (info "IMAP body data seqno" seqn "- size" (count s))))
                      (.once stream "end" end-cb)))
          msg-cb (fn [msg seqn]
                   (let [buffer (atom [])]
                     (.on msg "body" (partial body-cb buffer seqn))
                     (.once msg "end" #(debug "IMAP msg end" seqn))))
          mb-cb (fn [mb err box]
                  (let [uid (str (inc (:last-read @cmp-state)) ":*")
                        s (clj->js ["UNDELETED" ["UID" uid]])
                        cb (fn [err res]
                             (let [parsed-res (js->clj res)]
                               (when (and (seq parsed-res) (> (last parsed-res) (:last-read @cmp-state)))
                                 (let [last-read (last parsed-res)
                                       f (.fetch mb res (clj->js {:bodies ["TEXT"]
                                                                  :struct true}))]
                                   (info "search fetch" res)
                                   (swap! cmp-state assoc :last-read last-read)
                                   (.on f "message" msg-cb)
                                   (.once f "error" #(error "Fetch error" %))
                                   (.once f "end" (fn [] (info "IMAP mb-cb2 fetch ended") (.end mb)))))))]
                    (.search mb s cb)))]
      (imap-open (:mailbox mb) mb-cb)
      {})))

(defn write-email [{:keys [msg-payload]}]
  (when-let [mb-cfg (:write (:sync (imap-cfg)))]
    (imap-open
      (:mailbox mb-cfg)
      (fn [mb _err _box]
        (let [secret (:secret mb-cfg)
              cipher-hex (mue/encrypt-aes-hex (pr-str msg-payload) secret)
              decrypted (mue/decrypt-aes-hex cipher-hex secret)
              _ (when-not (= msg-payload decrypted)
                  (warn "not equal" (data/diff msg-payload decrypted)))
              cb (fn [_err rfc-2822]
                   (debug "RFC2822\n" rfc-2822)
                   (.append mb rfc-2822 #(if % (error "IMAP write" %)
                                               (info "IMAP wrote message"))))]
          (-> (BuildMail. "text/plain")
              (.setContent cipher-hex)
              (.setHeader "subject" (str (:timestamp msg-payload) " " (:vclock msg-payload)))
              (.build cb))))))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    (fn [_put-fn] {:state (atom {:last-read 0})})
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:sync/imap      write-email
                 :sync/read-imap read-email}})
