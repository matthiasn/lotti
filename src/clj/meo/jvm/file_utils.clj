(ns meo.jvm.file-utils
  (:require [clj-uuid :as uuid]
            [clj-time.core :as time]
            [clj-time.format :as tf]
            [clojure.tools.logging :as log]
            [matthiasn.systems-toolbox.component :as st]
            [me.raynes.fs :as fs]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.tools.logging :as l]
            [clojure.pprint :as pp]))

(def data-path (or (System/getenv "DATA_PATH") "data"))
(def daily-logs-path (str data-path "/daily-logs/"))
(def bak-path (str data-path "/backup/"))
(def app-cache-file (str data-path "/cache.dat"))
(def clucy-path (str data-path "/clucy/"))
(def export-path (str data-path "/export/"))
(def img-path (str data-path "/images/"))

(defn paths []
  (let [trash-path (str data-path "/trash/")]
    (fs/mkdirs daily-logs-path)
    (fs/mkdirs bak-path)
    (fs/mkdirs clucy-path)
    (fs/mkdirs export-path)
    (fs/mkdirs trash-path)
    (fs/mkdirs img-path)
    {:data-path       data-path
     :app-cache       app-cache-file
     :backup-path     bak-path
     :daily-logs-path daily-logs-path
     :clucy-path      clucy-path
     :img-path        img-path
     :export-path     export-path
     :trash-path      trash-path}))

(defn write-conf [conf conf-path]
  (fs/mkdirs data-path)
  (spit conf-path (with-out-str (pp/pprint conf))))

(defn load-cfg
  "Load config from file. When not exists, use default config and write the
   default to data path."
  []
  (let [conf-path (str data-path "/conf.edn")
        questionnaires (edn/read-string (slurp (io/resource "questionnaires.edn")))
        conf (try (edn/read-string (slurp conf-path))
                  (catch Exception ex
                    (let [default (edn/read-string
                                    (slurp (io/resource "default-conf.edn")))]
                      (log/warn "No config found -> copying from default.")
                      (write-conf default conf-path)
                      default)))]
    (when-not (:node-id conf)
      (let [with-node-id (assoc-in conf [:node-id] (str (st/make-uuid)))]
        (write-conf with-node-id conf-path)))
    (update-in conf [:questionnaires] #(merge-with merge questionnaires %))))

(defn write-cfg [{:keys [msg-payload]}]
  (let [conf-path (str data-path "/conf.edn")
        bak-path (str bak-path "/conf-" (st/now) ".edn")
        pretty (with-out-str (pp/pprint msg-payload))]
    (fs/rename conf-path bak-path)
    (log/info "writing new config")
    (spit conf-path pretty)
    {:emit-msg [:backend-cfg/new msg-payload]}))
