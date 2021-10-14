(ns meins.electron.main.runtime
  (:require [cljs.nodejs :refer [process]]
            [clojure.set :as set]
            [clojure.string :as s]
            [clojure.tools.reader.edn :as edn]
            [electron :refer [app systemPreferences]]
            [fs :refer [existsSync mkdirSync readFileSync]]
            [path :refer [normalize]]
            [taoensso.timbre :refer [debug error info]]))

(def runtime-info
  (let [cwd (.cwd process)
        rp (.-resourcesPath process)
        repo-dir (s/includes? (s/lower-case rp) "electron")
        user-data (if repo-dir "/tmp/meins" (.getPath app "userData"))
        _ (when-not (existsSync user-data)
            (mkdirSync user-data))
        app-path (if repo-dir cwd (str rp "/app"))
        platform (.-platform process)                       ; e.g. darwin, win32
        download-path (.getPath app "downloads")
        data-path (str user-data "/data")
        playground-path (str user-data "/playground-data")
        encrypted-path (str user-data "/encrypted")
        ca-file (str data-path "/capabilities.edn")
        capabilities (when (existsSync ca-file)
                       (:capabilities (edn/read-string
                                        (readFileSync ca-file "utf-8"))))
        capabilities (if repo-dir
                       (set/union capabilities #{:dev-menu})
                       capabilities)
        temp-path (if (= platform "win32") (.getPath app "temp") "/tmp")
        logfile-electron (str (if repo-dir "./log" temp-path) "/meins-electron.log")
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
              :logfile-jvm      (str temp-path "/meins-jvm.log")
              :logdir           logdir
              :audio-path       (str data-path "/audio")
              :img-path         (str data-path "/images")
              :thumbs-path      (str data-path "/thumbs")
              :cache            (str user-data "/data/cache.dat")
              :icon-path        (str app-path "/resources/icon.png")
              :java             (str app-path "/bin/jlink/bin/java")
              :jar              (str app-path "/bin/jlink/meins.jar")
              :blink            (str app-path "/bin/blink1-mac-cli")
              :user-data        user-data
              :cwd              cwd
              :pid-file         (str data-path "/meins.pid")
              :pg-pid-file      (str playground-path "/meins.pid")
              :resources-path   rp
              :version          (.getVersion app)
              :app-path         app-path}]
    (into {:repo-dir      repo-dir
           :index-page    (if repo-dir "resources/index-dev.html"
                                       "resources/index.html")
           :index-page-pg (if repo-dir "resources/index-pg-dev.html"
                                       "resources/index-pg.html")
           :help-page     (if repo-dir
                            "http://localhost:8765/help/manual.html"
                            "http://localhost:7788/help/manual.html")
           :port          (if repo-dir 8765 7788)
           :pg-port       (if repo-dir 8764 7787)
           :capabilities  capabilities
           :gql-port      (if repo-dir 8766 7789)}
          (map (fn [[k v]] [k (normalize v)]) info))))

(when (= "darwin" (:platform runtime-info))
  (-> (.askForMediaAccess systemPreferences "camera")
      (.then (fn [res]
               (let [status (.getMediaAccessStatus systemPreferences "camera")]
                 (info "askForMediaAccess" res)
                 (info "getMediaAccessStatus" status))))))
