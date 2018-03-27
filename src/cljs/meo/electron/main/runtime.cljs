(ns meo.electron.main.runtime
  (:require [path :refer [normalize join]]
            [electron :refer [app]]
            [cljs.nodejs :as nodejs :refer [process]]
            [clojure.string :as s]))

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
    (into {:repo-dir   repo-dir
           :index-page (if repo-dir "electron/index-dev.html" "electron/index.html")
           :port       (if repo-dir 8765 7788)}
          (map (fn [[k v]] [k (normalize v)]) info))))
