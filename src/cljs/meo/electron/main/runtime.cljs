(ns meo.electron.main.runtime
  (:require [path :refer [normalize join]]
            [electron :refer [app]]
            [cljs.nodejs :refer [process]]
            [taoensso.timbre :as timbre :refer-macros [info error debug]]
            [fs :refer [existsSync renameSync readFileSync]]
            [clojure.string :as s]
            [clojure.tools.reader.edn :as edn]))

(def runtime-info
  (let [user-data (.getPath app "userData")
        cwd (.cwd process)
        rp (.-resourcesPath process)
        repo-dir (s/includes? (s/lower-case rp) "electron")
        app-path (if repo-dir cwd (str rp "/app"))
        platform (.-platform process)                       ; e.g. darwin, win32
        download-path (.getPath app "downloads")
        data-path (str user-data "/data")
        encrypted-path (str user-data "/encrypted")
        ca-file (str (if repo-dir (str cwd "/data") data-path) "/capabilities.edn")
        capabilities (when (existsSync ca-file)
                       (edn/read-string (readFileSync ca-file "utf-8")))
        info {:platform        platform
              :download-path   download-path
              :electron-path   (first (.-argv process))
              :node-path       "/usr/local/bin/node"
              :data-path       data-path
              :daily-logs-path (str data-path "/daily-logs")
              :encrypted-path  encrypted-path
              :img-path        (str data-path "/images")
              :cache           (str user-data "/data/cache.dat")
              :java            (str app-path "/bin/jlink/bin/java")
              :jar             (str app-path "/bin/jlink/meo.jar")
              :blink           (str app-path "/bin/blink1-mac-cli")
              :user-data       user-data
              :cwd             cwd
              :pid-file        (str user-data "/meo.pid")
              :resources-path  rp
              :app-path        app-path}]
    (into {:repo-dir     repo-dir
           :index-page   (if repo-dir "electron/index-dev.html" "electron/index.html")
           :port         (if repo-dir 8765 7788)
           :capabilities (:capabilities capabilities)
           :gql-port     (if repo-dir 8766 7789)}
          (map (fn [[k v]] [k (normalize v)]) info))))
