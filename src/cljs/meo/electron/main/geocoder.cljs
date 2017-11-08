(ns meo.electron.main.geocoder
  (:require [taoensso.timbre :as timbre :refer-macros [info error debug]]
            [child_process :refer [spawn fork]]
            [electron :refer [app session shell]]
            [http :as http]
            [cljs.reader :refer [read-string]]
            [path :refer [join normalize]]
            [meo.electron.main.runtime :as rt]
            [process]
            [fs :refer [existsSync renameSync readFileSync]]
            [clojure.pprint :as pp]
            [clojure.string :as str]))

(defn fork-process [args opts]
  (info "forking" args opts)
  (fork (clj->js args) (clj->js opts)))

(defn serialize [msg-type msg-payload msg-meta]
  (let [serializable [msg-type {:msg-payload msg-payload :msg-meta msg-meta}]]
    (pr-str serializable)))

(defn relay-msg [{:keys [current-state msg-type msg-meta msg-payload]}]
  (let [geocoder (:geocoder current-state)
        serialized (serialize msg-type msg-payload msg-meta)]
    (debug "GEONAMES IPC sending" serialized)
    (.send geocoder serialized))
  {})

(defn start-geocoder [{:keys [current-state put-fn]}]
  (info "starting geocoder")
  (let [{:keys [user-data app-path cwd node-path]} rt/runtime-info
        geocoder (fork-process [(str app-path "/prod/geocoder/geocoder.js")]
                               {:detached false
                                :cwd      app-path})
        relay (fn [msg]
                (try
                  (let [parsed (read-string msg)
                        msg-type (first parsed)
                        {:keys [msg-payload msg-meta]} (second parsed)
                        msg (with-meta [msg-type msg-payload] msg-meta)]
                    (debug "IPC received" msg-type)
                    (put-fn msg))
                  (catch js/Object e (error e "when parsing" msg))))
        new-state (assoc-in current-state [:geocoder] geocoder)]
    (.on geocoder "message" relay)
    {:new-state new-state}))

(defn cmp-map [cmp-id relay-types]
  (let [relay-map (zipmap relay-types (repeat relay-msg))]
    {:cmp-id      cmp-id
     :handler-map (merge relay-map {:geocoder/start start-geocoder})}))
