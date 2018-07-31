(ns meo.ios.store
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [matthiasn.systems-toolbox.component :as st]
            [glittershark.core-async-storage :as as]
            [clojure.data.avl :as avl]
            [meo.ios.sync :as sync]
            [cljs.tools.reader.edn :as edn]
            [cljs.core.async :refer [<!]]
            [meo.ui.shared :as shared]))

(defn persist [{:keys [current-state put-fn msg-payload msg-meta]}]
  (let [{:keys [timestamp vclock id]} msg-payload
        last-vclock (:global-vclock current-state)
        instance-id (str (:instance-id current-state))
        new-vclock (update-in last-vclock [instance-id] #(inc (or % 0)))
        new-vclock (merge vclock new-vclock)
        offset (get-in new-vclock [instance-id])
        id (or id (st/make-uuid))
        prev (dissoc (get-in current-state [:entries timestamp])
                     :id :last-saved :vclock)
        entry (merge prev msg-payload {:last-saved (st/now)
                                       :id         (str id)
                                       :vclock     new-vclock})
        new-state (-> current-state
                      (assoc-in [:entries timestamp] entry)
                      (update-in [:all-timestamps] conj timestamp)
                      (assoc-in [:vclock-map offset] entry)
                      (assoc-in [:global-vclock] new-vclock))]
    (sync/write-to-imap (:secrets current-state) entry msg-meta put-fn)
    ;(shared/alert (str entry))
    (when-not (= prev (dissoc msg-payload :id :last-saved :vclock))
      (go (<! (as/set-item timestamp entry)))
      (go (<! (as/set-item :global-vclock last-vclock)))
      (go (<! (as/set-item :timestamps (:all-timestamps new-state))))
      {:new-state new-state})))

(defn detail [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:entry-detail] msg-payload)]
    {:new-state new-state}))

(defn theme [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:active-theme] msg-payload)]
    (go (<! (as/set-item :active-theme msg-payload)))
    {:new-state new-state}))

(defn current-activity [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:current-activity] msg-payload)]
    {:new-state new-state}))

(defn sync-start [{:keys [current-state msg-payload put-fn]}]
  (let [vclock-map (:vclock-map current-state)
        ;latest-synced (:latest-synced current-state)
        ;newer-than (:newer-than msg-payload latest-synced)
        instance-id (str (:instance-id current-state))
        offset (get-in msg-payload [:newer-than-vc instance-id])
        [_offset entry] (avl/nearest vclock-map > offset)
        new-state (assoc-in current-state [:latest-synced] offset)]
    (go (<! (as/set-item :latest-synced offset)))
    (if entry (put-fn [:sync/entry entry])
              (put-fn [:sync/done]))
    {:new-state new-state}))

(defn load-state [{:keys [cmp-state put-fn]}]
  (go
    (try
      (let [latest-vclock (second (<! (as/get-item :global-vclock)))]
        (put-fn [:debug/latest-vclock latest-vclock])
        (swap! cmp-state assoc-in [:global-vclock] latest-vclock))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (go
    (try
      (let [active-theme (second (<! (as/get-item :active-theme)))]
        (swap! cmp-state assoc-in [:active-theme] (or active-theme :light)))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (go
    (try
      (let [secrets (second (<! (as/get-item :secrets)))]
        (when secrets
          (swap! cmp-state assoc-in [:secrets] secrets)))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (go
    (try
      (let [latest-synced (second (<! (as/get-item :latest-synced)))]
        (put-fn [:debug/latest-synced latest-synced])
        (swap! cmp-state assoc-in [:latest-synced] latest-synced))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (go
    (try
      (let [instance-id (str (or (second (<! (as/get-item :instance-id)))
                                 (st/make-uuid)))
            timestamps (second (<! (as/get-item :timestamps)))]
        (swap! cmp-state assoc-in [:instance-id] instance-id)
        (swap! cmp-state update-in [:all-timestamps] into timestamps)
        (<! (as/set-item :instance-id instance-id))
        #_
        (doseq [ts timestamps]
          (let [entry (second (<! (as/get-item ts)))
                offset (get-in entry [:vclock instance-id])]
            (swap! cmp-state assoc-in [:entries ts] entry)
            (when offset
              (swap! cmp-state assoc-in [:vclock-map offset] entry)))))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (put-fn [:debug/state-fn-complete])
  {})

(defn state-reset [{:keys [cmp-state put-fn]}]
  (let [new-state {:entries       (avl/sorted-map)
                   :latest-synced 0}]
    (go (<! (as/clear)))
    (load-state {:cmp-state cmp-state :put-fn put-fn})
    {:new-state new-state}))

(defn set-secrets [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:secrets] msg-payload)]
    (go (<! (as/set-item :secrets msg-payload)))
    {:new-state new-state}))

(defn state-fn [put-fn]
  (let [state (atom {:entries        (avl/sorted-map)
                     :active-theme   :light
                     ;:all-timestamps (avl/sorted-set)
                     :all-timestamps (sorted-set)
                     :vclock-map     (avl/sorted-map)
                     :latest-synced  0})]
    (load-state {:cmp-state state
                 :put-fn    put-fn})
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/persist    persist
                 :entry/new        persist
                 :entry/detail     detail
                 :sync/initiate    sync-start
                 :sync/next        sync-start
                 :state/load       load-state
                 :state/reset      state-reset
                 :secrets/set      set-secrets
                 :theme/active     theme
                 :activity/current current-activity}})
