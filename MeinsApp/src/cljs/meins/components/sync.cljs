(ns meins.components.sync
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require ["@matthiasn/react-native-mailcore" :default MailCore]
            ["@react-native-community/netinfo" :as net-info]
            [cljs.core.async :refer [<!]]
            [cljs.reader :as edn]
            [cljs.spec.alpha :as spec]
            [clojure.string :as str]
            [expound.alpha :as exp]
            [glittershark.core-async-storage :as as]
            [meins.common.specs.imap]
            [meins.shared.encryption :as mse]
            [meins.ui.db :as uidb]
            [meins.ui.shared :as shared :refer [platform-os]]
            [meins.util.keychain :as kc]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [debug error info warn]]))

(defn extract-body [s]
  (-> (str s)
      (str/split "-")
      first
      (str/replace " " "")
      (str/replace "=\r\n" "")
      (str/replace "\r\n" "")
      (str/replace "\n" "")))

(defn validate-mail-cfg [cfg]
  (if (spec/valid? :meins.imap/server-app cfg)
    cfg
    (error "spec validation failed" (exp/expound-str :meins.imap/server-app cfg))))

(defn sync-write [{:keys [msg-type msg-payload put-fn cmp-state db-item]}]
  (info :sync-write)
  (when-let [secrets (:secrets @cmp-state)]
    (try
      (when (:online @cmp-state)
        (let [their-public-key (-> secrets :desktop :publicKey)
              our-secret-key (-> @cmp-state :key-pair :secretKey)
              folder (-> secrets :sync :write :folder)
              update-filename (fn [entry]
                                (if (:img_file entry)
                                  (update entry :img_file #(str/replace % ".PNG" ".JPG"))
                                  entry))
              serializable [msg-type {:msg-payload (update-filename msg-payload)
                                      :msg-meta    {}}]     ; save battery and bandwidth
              serialized (pr-str serializable)
              _ (info "their-public-key" their-public-key)
              hex-cipher (mse/encrypt-asymm serialized their-public-key our-secret-key)
              photo-uri (-> msg-payload :media :image :uri)
              filename (:img_file msg-payload)
              audiofile (:audio_file msg-payload)
              mb (-> secrets :server :username)
              mail-cfg (validate-mail-cfg
                         (merge (:server secrets)
                                {:folder   folder
                                 :from     {:addressWithDisplayName mb
                                            :mailbox                mb}
                                 :to       {:addressWithDisplayName mb
                                            :mailbox                mb}
                                 :subject  (str (:timestamp msg-payload))
                                 :textBody hex-cipher}
                                (when audiofile {:audiofile audiofile})
                                (when (and (= "android" platform-os) audiofile)
                                  {:audiopath (str "/data/data/com.matthiasn.meins/" audiofile)})
                                (when (and (= :entry/sync msg-type) filename photo-uri)
                                  {:attachmentUri photo-uri
                                   :filename      filename})))
              _ (info mail-cfg)
              success-cb (fn []
                           (when db-item
                             (.write @uidb/realm-db #(set! (.-sync db-item) "DONE"))
                             (put-fn [:schedule/new {:timeout 100
                                                     :message [:sync/retry]
                                                     :id      :sync}])))
              error-cb (fn [err]
                         (when db-item
                           (.write @uidb/realm-db #(set! (.-sync db-item) "ERROR"))
                           (error "write error-cb" (js->clj err))
                           (put-fn [:schedule/new {:timeout 10000
                                                   :message [:sync/retry]
                                                   :id      :sync}])))]
          (swap! cmp-state update-in [:open-writes] conj msg-payload)
          (if (and hex-cipher folder)
            (when mail-cfg
              (-> (.loginImapWrite MailCore (clj->js mail-cfg))
                  (.then (fn [res]
                           (info res)
                           (.write @uidb/realm-db #(set! (.-sync db-item) "STARTED"))
                           (-> (.saveImap MailCore (clj->js mail-cfg))
                               (.then success-cb)
                               (.catch error-cb))))
                  (.catch error-cb)))
            (error "ciphertext" hex-cipher "folder" folder))))
      (catch :default e (error (str e)))))
  {})

(defn schedule-read [cmp-state put-fn]
  (when (seq (:not-fetched @cmp-state))
    (put-fn [:schedule/new
             {:timeout 1000
              :message [:sync/read]}])))

(defn sync-get-uids [{:keys [put-fn cmp-state current-state]}]
  (when-let [secrets (:secrets @cmp-state)]
    (when (:online current-state)
      (try
        (let [folder (-> secrets :sync :read :folder)
              min-uid (or (last (:not-fetched current-state))
                          (inc (:last-uid-read current-state)))
              mail-cfg (validate-mail-cfg (merge (:server secrets)
                                                 {:folder folder
                                                  :minUid min-uid
                                                  :length 1000}))
              fetch-cb (fn [data]
                         (info "fetch-cb min-uid folder" min-uid folder)
                         (info "fetch-cb data" data)
                         (let [uids (edn/read-string (str "[" data "]"))]
                           (info "fetch-cb" data)
                           (swap! cmp-state update :not-fetched into uids)
                           (schedule-read cmp-state put-fn)))]
          (when mail-cfg
            #_(-> (.fetchImap MailCore (clj->js mail-cfg))
                  (.then fetch-cb)
                  (.catch #(error (str %))))

            (-> (.loginImap MailCore (clj->js mail-cfg))
                (.then (fn [res]
                         (info res)
                         (-> (.fetchImap MailCore (clj->js mail-cfg))
                             (.then fetch-cb)
                             (.catch #(error (str %))))))
                (.catch #(error (str %))))))
        (catch :default e (error (str e))))))
  {})

(defn sync-read-msg [{:keys [put-fn cmp-state current-state]}]
  (when-let [secrets (:secrets current-state)]
    (try
      (when (:online current-state)
        (let [{:keys [fetched not-fetched]} @cmp-state
              their-public-key (-> secrets :desktop :publicKey)
              our-private-key (-> @cmp-state :key-pair :secretKey)
              not-fetched (drop-while #(contains? fetched %) not-fetched)]
          (when-let [uid (first not-fetched)]
            (let [folder (-> secrets :sync :read :folder)
                  mail-cfg (validate-mail-cfg (merge (:server secrets)
                                                     {:folder      folder
                                                      :messageId   uid
                                                      :requestKind 0
                                                      :uid         uid}))
                  fetch-cb (fn [data]
                             (schedule-read cmp-state put-fn)
                             (info data)
                             (let [body (get (js->clj data) "body")
                                   decrypted (mse/decrypt body their-public-key our-private-key)
                                   msg-type (first decrypted)
                                   {:keys [msg-payload msg-meta]} (second decrypted)
                                   msg (with-meta [msg-type msg-payload]
                                                  (assoc msg-meta :from-sync true))]
                               (swap! cmp-state assoc-in [:last-uid-read] uid)
                               (go (<! (as/set-item :last-uid-read uid)))
                               (swap! cmp-state update-in [:not-fetched] disj uid)
                               (swap! cmp-state update-in [:fetched] conj uid)
                               (put-fn msg)
                               (schedule-read cmp-state put-fn)))]
              (when mail-cfg
                (-> (.getMailByUid MailCore (clj->js mail-cfg))
                    (.then fetch-cb)
                    (.catch #(error (js->clj %))))
                #_
                (-> (.loginImap MailCore (clj->js mail-cfg))
                    (.then (fn [res]
                             (info res)
                             (-> (.getMailByUid MailCore (clj->js mail-cfg))
                                 (.then fetch-cb)
                                 (.catch #(error (js->clj %))))
                             #_(-> (.fetchImapByUid MailCore (clj->js mail-cfg))
                                   (.then fetch-cb)
                                   (.catch #(error (js->clj %))))
                             ))
                    (.catch #(error (str %)))))))))
      (catch :default e (error (str e)))))
  {})

(defn retry-write [{:keys [cmp-state current-state put-fn]}]
  (let [cfg (subscribe [:cfg])
        res (some-> @uidb/realm-db
                    (.objects "Entry")
                    (.filtered "sync == \"OPEN\"")
                    (.slice 0 1))]
    (when (and (:online current-state) (:sync-active @cfg))
      (doseq [x res]
        (sync-write {:db-item     x
                     :cmp-state   cmp-state
                     :put-fn      put-fn
                     :msg-type    :entry/sync
                     :msg-payload (edn/read-string (aget x "edn"))}))))
  {})

(defn set-secrets [{:keys [current-state msg-payload]}]
  (let [new-state (-> current-state
                      (assoc-in [:secrets] msg-payload)
                      (assoc-in [:last-uid-read] 0))]
    (go (<! (as/set-item :last-uid-read 0)))
    (info "set-secrets" (str msg-payload))
    {:new-state new-state}))

(defn set-key-pair [{:keys [current-state msg-payload]}]
  (info "set-key-pair" (str msg-payload))
  (let [new-state (assoc-in current-state [:key-pair] msg-payload)]
    {:new-state new-state}))

(defn state-fn [put-fn]
  (let [state (atom {:last-uid-read 0
                     :not-fetched   (sorted-set)
                     :open-writes   #{}
                     :fetched       #{}
                     :online        false})
        listener (fn [ev]
                   (swap! state assoc :online (.-isInternetReachable ev)))]
    (.addEventListener net-info listener)
    (kc/get-keypair #(swap! state assoc :key-pair %))
    (go (try
          (when-let [secrets (second (<! (as/get-item :secrets)))]
            (swap! state assoc-in [:secrets] secrets))
          (catch js/Object e
            (put-fn [:debug/error {:msg e}]))))
    (go (try
          (when-let [uid (second (<! (as/get-item :last-uid-read)))]
            (swap! state assoc-in [:last-uid-read] uid))
          (catch js/Object e
            (put-fn [:debug/error {:msg e}]))))
    {:state state}))

(defn when-active [f]
  (fn [{:keys [observed] :as m}]
    (when (-> @observed :cfg :sync-active)
      (f m))))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:sync/fetch     (when-active sync-get-uids)
                 :sync/retry     (when-active retry-write)
                 :sync/read      (when-active sync-read-msg)
                 :secrets/set    set-secrets
                 :secrets/set-kp set-key-pair}})
