(ns meo.electron.main.runtime
  (:require [path :refer [normalize join]]
            [electron :refer [app]]
            [cljs.nodejs :refer [process]]
            [taoensso.timbre :refer-macros [info error debug]]
            [fs :refer [existsSync renameSync readFileSync]]
            [clojure.string :as s]
            [clojure.tools.reader.edn :as edn]
            [clojure.set :as set]))

(def runtime-info
  (let [cwd (.cwd process)
        rp (.-resourcesPath process)
        repo-dir (s/includes? (s/lower-case rp) "electron")
        user-data (if repo-dir "/tmp/meo" (.getPath app "userData"))
        app-path (if repo-dir cwd (str rp "/app"))
        platform (.-platform process)                       ; e.g. darwin, win32
        download-path (.getPath app "downloads")
        data-path (str user-data "/data")
        playground-path (str user-data "/playground-data")
        encrypted-path (str user-data "/encrypted")
        ca-file (str (if repo-dir (str cwd "/data") data-path) "/capabilities.edn")
        capabilities (when (existsSync ca-file)
                       (:capabilities (edn/read-string
                                        (readFileSync ca-file "utf-8"))))
        capabilities (if repo-dir
                       (set/union capabilities #{:dev-menu})
                       capabilities)
        temp-path (if (= platform "win32") (.getPath app "temp") "/tmp")
        logfile-electron (str (if repo-dir "./log" temp-path) "/meo-electron.log")
        logdir (str (if repo-dir "./log" temp-path) "/")
        info {:platform         platform
              :download-path    download-path
              :electron-path    (first (.-argv process))
              :node-path        "/usr/local/bin/node"
              :data-path        data-path
              :manual-path      (str app-path "/doc")
              :playground-path  playground-path
              :daily-logs-path  (str data-path "/daily-logs")
              :encrypted-path   encrypted-path
              :logfile-electron logfile-electron
              :logfile-jvm      (str temp-path "/meo-jvm.log")
              :logdir           logdir
              :audio-path       (str data-path "/audio")
              :img-path         (str data-path "/images")
              :thumbs-path      (str data-path "/thumbs")
              :cache            (str user-data "/data/cache.dat")
              :icon-path        (str app-path "/resources/icon.png")
              :java             (str app-path "/bin/jlink/bin/java")
              :jar              (str app-path "/bin/jlink/meo.jar")
              :blink            (str app-path "/bin/blink1-mac-cli")
              :user-data        user-data
              :cwd              cwd
              :pid-file         (str data-path "/meo.pid")
              :pg-pid-file      (str playground-path "/meo.pid")
              :resources-path   rp
              :version          (.getVersion app)
              :app-path         app-path}]
    (into {:repo-dir      repo-dir
           :index-page    (if repo-dir "electron/index-dev.html" "electron/index.html")
           :index-page-pg (if repo-dir "electron/index-pg-dev.html" "electron/index-pg.html")
           :help-page     (if repo-dir
                            "http://localhost:8765/help/manual.html"
                            "http://localhost:7788/help/manual.html")
           :port          (if repo-dir 8765 7788)
           :pg-port       (if repo-dir 8764 7787)
           :capabilities  capabilities
           :gql-port      (if repo-dir 8766 7789)}
          (map (fn [[k v]] [k (normalize v)]) info))))
