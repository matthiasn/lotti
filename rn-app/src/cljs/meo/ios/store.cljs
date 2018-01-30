(ns meo.ios.store
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [matthiasn.systems-toolbox.component :as st]
            [glittershark.core-async-storage :as as]
            [clojure.data.avl :as avl]
            [cljs.core.async :refer [<!]]))

(defn persist [{:keys [current-state put-fn msg-payload]}]
  (let [{:keys [timestamp vclock id]} msg-payload
        last-vclock (:latest-vclock current-state)
        instance-id (:instance-id current-state)
        new-vclock (update-in last-vclock [instance-id] #(inc (or % 0)))
        new-vclock (merge vclock new-vclock)
        id (or id (st/make-uuid))
        entry (merge msg-payload
                     {:last-saved (st/now)
                      :id         (str id)
                      :vclock     new-vclock})
        new-state (-> current-state
                      (assoc-in [:entries timestamp] entry)
                      (assoc-in [:latest-vclock] new-vclock))
        prev (dissoc (get-in current-state [:entries timestamp])
                     :id :last-saved :vclock)]
    (when-not (= prev (dissoc msg-payload :id :last-saved :vclock))
      (put-fn [:entry/persisted entry])
      (go (<! (as/set-item timestamp entry)))
      (go (<! (as/set-item :latest-vclock last-vclock)))
      (go (<! (as/set-item :timestamps (set (keys (:entries new-state))))))
      {:new-state new-state})))

(defn geo-enrich [{:keys [current-state msg-payload]}]
  (let [ts (:timestamp msg-payload)
        geo-info (select-keys msg-payload [:latitude :timestamp :longitude])
        prev (get-in current-state [:entries ts])
        merged (merge prev geo-info)
        new-state (assoc-in current-state [:entries ts] merged)]
    (when prev
      (go (<! (as/set-item ts merged)))
      {:new-state new-state})))

(defn detail [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:entry-detail] msg-payload)]
    {:new-state new-state}))

(defn theme [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:active-theme] msg-payload)]
    {:new-state new-state}))

(defn sync-start [{:keys [current-state msg-payload put-fn]}]
  (let [entries (:entries current-state)
        latest-synced (:latest-synced current-state)
        newer-than (:newer-than msg-payload latest-synced)
        [ts entry] (avl/nearest entries > newer-than)
        new-state (assoc-in current-state [:latest-synced] newer-than)]
    (go (<! (as/set-item :latest-synced newer-than)))
    (when entry (put-fn [:sync/entry (merge entry {:timestamp ts})]))
    {:new-state new-state}))

(defn state-reset [{:keys []}]
  (let [new-state {:entries       (avl/sorted-map)
                   :latest-synced 0}]
    (go (<! (as/set-item :latest-synced 0)))
    {:new-state new-state}))

(defn load-state [{:keys [cmp-state put-fn]}]
  (go
    (try
      (let [latest-vclock (second (<! (as/get-item :latest-vclock)))]
        (put-fn [:debug/latest-vclock latest-vclock])
        (swap! cmp-state assoc-in [:latest-vclock] latest-vclock))
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
                                 (st/make-uuid)))]
        (swap! cmp-state assoc-in [:instance-id] instance-id)
        (put-fn [:debug/instance-id instance-id])
        (<! (as/set-item :instance-id instance-id)))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (go
    (try
      (let [timestamps (second (<! (as/get-item :timestamps)))]
        (doseq [ts timestamps]
          (let [entry (second (<! (as/get-item ts)))]
            (put-fn [:debug/entry entry])
            (swap! cmp-state assoc-in [:entries ts] entry))))
      (catch js/Object e
        (put-fn [:debug/error {:msg e}]))))
  (put-fn [:debug/state-fn-complete])
  {})

(defn state-fn [put-fn]
  (let [state (atom {:entries       (avl/sorted-map)
                     :active-theme  :light
                     :latest-synced 0})]
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/persist    persist
                 :entry/new        persist
                 :entry/geo-enrich geo-enrich
                 :sync/initiate    sync-start
                 :state/load       load-state
                 :state/reset      state-reset
                 :entry/detail     detail
                 :theme/active     theme
                 :sync/next        sync-start}})
