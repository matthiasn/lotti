(ns meo.ios.store
  (:require [matthiasn.systems-toolbox.component :as st]
            [glittershark.core-async-storage :as as]
            [clojure.data.avl :as avl]
            [cljs.core.async :refer [<!]])
  (:require-macros [cljs.core.async.macros :refer [go]]))

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

(defn sync-start [{:keys [current-state msg-payload put-fn]}]
  (let [entries (:entries current-state)
        newer-than (:newer-than msg-payload 0)
        entry (second (avl/nearest entries > newer-than))]
    (when entry (put-fn [:sync/entry entry]))
    {}))

(defn state-fn [put-fn]
  (let [state (atom {:entries (avl/sorted-map)})]
    (go
      (let [latest-vclock (second (<! (as/get-item :latest-vclock)))]
        (swap! state assoc-in [:latest-vclock] latest-vclock)))
    (go
      (let [instance-id (str (or (second (<! (as/get-item :instance-id)))
                                 (st/make-uuid)))]
        (swap! state assoc-in [:instance-id] instance-id)
        (<! (as/set-item :instance-id instance-id))))
    (go
      (let [timestamps (second (<! (as/get-item :timestamps)))]
        (doseq [ts timestamps]
          (swap! state assoc-in [:entries ts] (second (<! (as/get-item ts)))))))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/persist persist
                 :entry/new     persist
                 :sync/initiate sync-start
                 :sync/next     sync-start}})
