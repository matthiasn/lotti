(ns meo.ios.store
  (:require [matthiasn.systems-toolbox.component :as st]
            [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]])
  (:require-macros [cljs.core.async.macros :refer [go]]))

(def device-info (js/require "react-native-device-info"))

(defn persist [{:keys [current-state put-fn msg-payload]}]
  (let [{:keys [timestamp vclock id]} msg-payload
        last-vclock (:latest-vclock current-state)
        device-id (.getUniqueID device-info)
        new-vclock (update-in last-vclock [device-id] #(inc (or % 0)))
        new-vclock (merge vclock new-vclock)
        id (or id (st/make-uuid))
        entry (merge msg-payload
                     {:last-saved (st/now)
                      :id         id
                      :vclock     new-vclock})
        new-state (-> current-state
                      (assoc-in [:entries timestamp] entry)
                      (assoc-in [:latest-vclock] new-vclock))
        prev (dissoc (get-in current-state [:entries timestamp])
                     :id :last-saved :vclock)]
    (when-not (= prev (dissoc msg-payload :id :last-saved :vclock))
      (go (<! (as/set-item timestamp entry)))
      (go (<! (as/set-item :latest-vclock last-vclock)))
      (go (<! (as/set-item :timestamps (set (keys (:entries new-state))))))
      {:new-state new-state})))

(defn state-fn [put-fn]
  (let [state (atom {})
        device-id (.getUniqueID device-info)]
    (go
      (let [latest-vclock (second (<! (as/get-item :latest-vclock)))]
        (swap! state assoc-in [:latest-vclock] latest-vclock)))
    (go
      (let [timestamps (second (<! (as/get-item :timestamps)))]
        (doseq [ts timestamps]
          (swap! state assoc-in [:entries ts] (second (<! (as/get-item ts)))))))
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:entry/update persist
                 :entry/new    persist}})
