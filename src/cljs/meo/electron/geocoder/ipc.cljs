(ns meo.electron.geocoder.ipc
  (:require [taoensso.timbre :as timbre :refer-macros [info error debug]]
            [process]
            [cljs.reader :refer [read-string]]))

(defn serialize [msg-type msg-payload msg-meta]
  (let [serializable [msg-type {:msg-payload msg-payload :msg-meta msg-meta}]]
    (pr-str serializable)))

(defn relay-msg [{:keys [current-state msg-type msg-meta msg-payload]}]
  (let [serialized (serialize msg-type msg-payload msg-meta)]
    (debug "GEONAMES IPC sending" serialized)
    (.send process serialized))
  {})

(defn state-fn [put-fn]
  (let [state (atom {})
        relay (fn [msg]
                (try
                  (let [parsed (read-string msg)
                        msg-type (first parsed)
                        {:keys [msg-payload msg-meta]} (second parsed)
                        msg (with-meta [msg-type msg-payload] msg-meta)]
                    (debug "IPC received" msg-type)
                    (put-fn msg))
                  (catch js/Object e (error e "when parsing" msg))))]
    (info "Starting GEONAMES IPC")
    (.on process "message" relay)
    {:state state}))

(defn cmp-map [cmp-id relay-types]
  (let [relay-map (zipmap relay-types (repeat relay-msg))]
    {:cmp-id      cmp-id
     :state-fn    state-fn
     :handler-map relay-map}))
