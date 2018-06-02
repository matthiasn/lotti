(ns meo.electron.main.runtime
  (:require [path :refer [normalize join]]
            [electron :refer [app]]
            [cljs.nodejs :refer [process]]
            [taoensso.timbre :as timbre :refer-macros [info error debug]]
            [fs :refer [existsSync renameSync readFileSync]]
            [clojure.string :as s]
            [clojure.tools.reader.edn :as edn]
            [clojure.set :as set]))

(def runtime-info
  (let [cwd (.cwd process)
        rp (.-resourcesPath process)
        repo-dir (s/includes? (s/lower-case rp) "electron")
        user-data (if repo-dir cwd (.getPath app "userData"))
        app-path (if repo-dir cwd (str rp "/app"))
        platform (.-platform process)                       ; e.g. darwin, win32
        download-path (.getPath app "downloads")
        data-path (str user-data "/data")
        encrypted-path (str user-data "/encrypted")
        ca-file (str (if repo-dir (str cwd "/data") data-path) "/capabilities.edn")
        capabilities (when (existsSync ca-file)
                       (:capabilities (edn/read-string
                                        (readFileSync ca-file "utf-8"))))
        capabilities (if repo-dir
                       (set/union capabilities #{:dev-menu})
                       capabilities)
        temp-path (.getPath app "temp")
        logfile-electron (str (if repo-dir "./log" temp-path) "/meo-electron.log")
        logdir (str (if repo-dir "./log" temp-path) "/")
        info {:platform         platform
              :download-path    download-path
              :electron-path    (first (.-argv process))
              :node-path        "/usr/local/bin/node"
              :data-path        data-path
              :daily-logs-path  (str data-path "/daily-logs")
              :encrypted-path   encrypted-path
              :logfile-electron logfile-electron
              :logfile-jvm      (str temp-path "/meo-jvm.log")
              :logdir           logdir
              :img-path         (str data-path "/images")
              :thumbs-path      (str data-path "/thumbs")
              :cache            (str user-data "/data/cache.dat")
              :java             (str app-path "/bin/jlink/bin/java")
              :jar              (str app-path "/bin/jlink/meo.jar")
              :blink            (str app-path "/bin/blink1-mac-cli")
              :user-data        user-data
              :cwd              cwd
              :pid-file         (str user-data "/meo.pid")
              :resources-path   rp
              :app-path         app-path}]
    (into {:repo-dir     repo-dir
           :index-page   (if repo-dir "electron/index-dev.html" "electron/index.html")
           :port         (if repo-dir 8765 7788)
           :capabilities capabilities
           :gql-port     (if repo-dir 8766 7789)}
          (map (fn [[k v]] [k (normalize v)]) info))))
