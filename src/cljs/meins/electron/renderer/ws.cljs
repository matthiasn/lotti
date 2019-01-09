(ns meins.electron.renderer.ws
  (:require [taoensso.timbre :refer-macros [info debug]]
            [cljs.reader :as edn]
            [reconnectingwebsocket]
            [clojure.string :as s]))

(defn deserialize-meta [payload]
  (let [[cmd-type {:keys [msg msg-meta]}] payload]
    (with-meta [cmd-type msg] msg-meta)))

(defn state-fn [put-fn]
  (let [port (dec (js/parseInt (second (s/split (.-iwwHOST js/window) ":"))))
        host (str "ws://localhost:" port "/ws")
        ws (reconnectingwebsocket. host)
        state (atom {:ws   ws
                     :open false})
        on-msg (fn [ev]
                 (let [data (.-data ev)
                       deserialized (edn/read-string data)]
                   (debug "received" deserialized)
                   (when (vector? deserialized)
                     (let [msg (deserialize-meta deserialized)]
                       (debug "received" msg)
                       (put-fn msg)))))
        open #(let [waiting (:waiting @state)
                    cnt (count waiting)]
                (when (pos? cnt)
                  (info "sending" cnt "messages")
                  (doseq [msg waiting]
                    (debug "sending" msg)
                    (.send ws msg))
                  (swap! state assoc-in [:waiting] nil))
                (swap! state assoc-in [:open] true))
        on-close #(info "connection closed - reconnecting")]
    (aset ws "onmessage" on-msg)
    (aset ws "onopen" open)
    (aset ws "onclose" on-close)
    {:state state}))

(defn all-msgs-handler [{:keys [current-state msg-meta msg-payload msg-type]}]
  (let [ws (:ws current-state)
        serialized (pr-str [msg-type {:msg      msg-payload
                                      :msg-meta msg-meta}])]
    (if (:open current-state)
      (do (.send ws serialized)
          {})
      (let [new-state (update-in current-state [:waiting] conj serialized)]
        {:new-state new-state}))))

(defn cmp-map [cmp-id cfg]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:validate-in    false
                 :validate-out   false
                 :validate-state false}
   :handler-map (zipmap (:relay-types cfg) (repeat all-msgs-handler))})
