(ns meins.jvm.file-utils
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]
            [clojure.string :as s]
            [meins.common.utils.misc :as m]
            [matthiasn.systems-toolbox.component :as st]
            [me.raynes.fs :as fs]
            [taoensso.timbre :refer [info warn]]))

(def app-path (or (System/getenv "APP_PATH") "."))

(def platform (m/lower-case (System/getProperty "os.name")))
(def tmp-dir (System/getProperty "java.io.tmpdir"))
(def data-path (or (System/getenv "DATA_PATH")
                   (if (s/includes? platform "windows")
                     (str tmp-dir "/meins/data")
                     "/tmp/meins/data")))

(def pid-file (str data-path "/meins.pid"))
(def audio-path (str data-path "/audio/"))
(def daily-logs-path (str data-path "/daily-logs/"))
(def bak-path (str data-path "/backup/"))
(def app-cache-file (str data-path "/cache.dat"))
(def clucy-path (str data-path "/clucy/"))
(def export-path (str data-path "/export/"))
(def img-path (str data-path "/images/"))
(def thumbs-path (str data-path "/thumbs/"))
(def thumbs-256 (str data-path "/thumbs/256/"))
(def thumbs-512 (str data-path "/thumbs/512/"))
(def thumbs-2048 (str data-path "/thumbs/2048/"))
(def repos-path (str data-path "/repos.edn"))

(defn load-repos []
  (try (edn/read-string (slurp repos-path))
       (catch Exception _
         (warn "No repos config found.")
         {:repos {}})))

(defn paths []
  (let [trash-path (str data-path "/trash/")]
    (fs/mkdirs daily-logs-path)
    (fs/mkdirs audio-path)
    (fs/mkdirs bak-path)
    (fs/mkdirs clucy-path)
    (fs/mkdirs export-path)
    (fs/mkdirs trash-path)
    (fs/mkdirs img-path)
    (fs/mkdirs thumbs-path)
    (fs/mkdirs thumbs-256)
    (fs/mkdirs thumbs-512)
    (fs/mkdirs thumbs-2048)
    {:data-path       data-path
     :app-cache       app-cache-file
     :app-path        app-path
     :backup-path     bak-path
     :audio-path      audio-path
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
        questionnaires-path (str data-path "/questionnaires.edn")
        questionnaires (try (edn/read-string (slurp questionnaires-path))
                            (catch Exception _
                              (warn "No questionnaires config found.")
                              {}))
        ca-path (str data-path "/capabilities.edn")
        capabilities (try (edn/read-string (slurp ca-path))
                          (catch Exception _
                            (warn "No capabilities config found.")
                            {}))
        conf (try (edn/read-string (slurp conf-path))
                  (catch Exception _
                    (let [default (edn/read-string
                                    (slurp (io/resource "default-conf.edn")))]
                      (warn "No config found -> copying from default.")
                      (write-conf default conf-path)
                      default)))
        conf (assoc-in conf [:repos] (:repos (load-repos)))]
    (when-not (:node-id conf)
      (let [with-node-id (assoc-in conf [:node-id] (str (st/make-uuid)))]
        (write-conf with-node-id conf-path)))
    (-> conf
        (update-in [:questionnaires] #(merge-with merge questionnaires %))
        (assoc-in [:capabilities] (:capabilities capabilities)))))

(defn write-cfg [{:keys [msg-payload]}]
  (let [conf-path (str data-path "/conf.edn")
        bak-path (str bak-path "/conf-" (st/now) ".edn")
        pretty (with-out-str (pp/pprint msg-payload))]
    (fs/rename conf-path bak-path)
    (info "writing new config")
    (spit conf-path pretty)
    {:emit-msg [:backend-cfg/new msg-payload]}))
