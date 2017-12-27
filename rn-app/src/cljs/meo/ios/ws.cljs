(ns meo.ios.ws
  (:require [matthiasn.systems-toolbox-sente.client :as client]))

(defn connect [{:keys [current-state msg-payload put-fn]}]
  (let [cfg (:cfg current-state)
        cfg (update-in cfg [:sente-opts] merge msg-payload)
        state-fn (client/client-state-fn cfg)
        ws (:state (state-fn put-fn))
        new-state (assoc-in current-state [:ws] ws)]
    {:new-state new-state
     :emit-msg [:ws/connected (str ws)]}))

(defn all-msgs-handler [msg-map]
  (let [ws (-> msg-map :current-state :ws)]
    (when ws
      (client/all-msgs-handler (merge msg-map {:cmp-state ws})))
    {}))

(defn state-fn [cfg]
  (fn state-fn [_put-fn]
    (let [state (atom {:cfg          cfg
                       :request-tags (atom {})})]
      {:state state})))

(defn cmp-map [cmp-id cfg]
  (let [msg-types (:relay-types cfg)]
    {:cmp-id      cmp-id
     :state-fn    (state-fn cfg)
     :handler-map (merge
                    (zipmap msg-types (repeat all-msgs-handler))
                    {:ws/connect connect})}))
