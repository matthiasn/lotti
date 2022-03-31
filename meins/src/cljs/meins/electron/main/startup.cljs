(ns meins.electron.main.startup
  (:require ["child_process" :refer [spawn]]
            ["electron" :refer [app session shell]]
            ["find-process" :as find-process]
            ["fs" :refer [existsSync readFileSync renameSync writeFileSync]]
            ["http" :as http]
            [cljs.reader :refer [read-string]]
            [clojure.string :as str]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :refer [error info]]))

(def PORT (:port rt/runtime-info))
(def data-path (:data-path rt/runtime-info))
(def cfg-path (str data-path "/window.edn"))

(defn window-cfg []
  (when (existsSync cfg-path)
    (read-string (readFileSync cfg-path "utf-8"))))

(defn spawn-process [cmd args opts]
  (info "STARTUP: spawning" cmd args opts)
  (spawn cmd (clj->js args) (clj->js opts)))

(defn kill [pid]
  (info "Killing PID" pid)
  (when pid
    (if (= (:platform rt/runtime-info) "win32")
      (spawn-process "TaskKill" ["-F" "/PID" pid] {})
      (spawn-process "/bin/kill" ["-KILL" pid] {}))))

(defn kill-by-port-lsof
  "Kill process for port by calling lsof on Linux and Mac
   in addition to using find-process, as the latter worked
   fine on Mac and Windows but not on Linux."
  [port]
  (let [platform (:platform rt/runtime-info)
        lsof-path (case platform
                    "darwin" "/usr/sbin/lsof"
                    "linux" "/usr/bin/lsof"
                    nil)]
    (when lsof-path
      (let [lsof (spawn-process lsof-path ["-n" (str "-i4TCP:" port)] {})
            stdout (aget lsof "stdout")
            cb (fn [data]
                 (let [lines (str/split-lines data)
                       line (first (filter #(str/includes? % "java") lines))
                       pid (re-find #"[0-9]{1,5}" (str line))
                       pid (when pid (js/parseInt pid))]
                   (when pid (kill pid))))]
        (.on stdout "data" cb)))))

(defn kill-by-port [port]
  (info "Killing process for port" port)
  (kill-by-port-lsof port)
  (let [find (find-process "port" port)
        cb (fn [processes]
             (doseq [proc processes]
               (info "About to kill process" proc)
               (kill (.-pid proc))))]
    (.then find cb)))

(defn window-resized [{:keys [msg-payload]}]
  (let [bounds (pr-str msg-payload)]
    (info "window was resized" msg-payload)
    (writeFileSync cfg-path bounds))
  {})

(defn jvm-up? [{:keys [put-fn current-state cmp-state msg-payload]}]
  (info "JVM up?" (:attempt current-state) msg-payload)
  (let [{:keys [version icon repo-dir]} rt/runtime-info
        environment (:environment msg-payload)
        port (if (= environment :live) PORT (:pg-port rt/runtime-info))
        index-page (if (= environment :live)
                     (:index-page rt/runtime-info)
                     (:index-page-pg rt/runtime-info))
        loading-page (if (= environment :live)
                       "resources/loading.html"
                       "resources/loading-playground.html")
        try-again
        (fn [_]
          (info "- Nope, trying again")
          (when-not (-> @cmp-state :service environment)
            (put-fn [:schedule/new {:timeout 10 :message [:jvm/start msg-payload]}]))
          (put-fn [:window/new {:url       loading-page
                                :width     400
                                :height    300
                                :opts      {:icon icon}
                                :window-id loading-page}])
          (put-fn [:schedule/new {:timeout 1000 :message [:jvm/loaded? msg-payload]}]))
        res-handler
        (fn [res]
          (let [status-code (.-statusCode res)
                opts {:titleBarStyle   "hidden"
                      :backgroundColor "#282828"
                      :icon            icon
                      :webPreferences  (merge {:nodeIntegration true}
                                              (when repo-dir
                                                {:webSecurity false}))}
                msg (merge
                      (window-cfg)
                      {:url         index-page
                       :save-bounds true
                       :opts        opts}
                      (when (= environment :playground)
                        {:window-id index-page}))
                data (atom "")
                version-handler
                (fn [_]
                  (try
                    (let [package-json (.parse js/JSON @data)
                          backend-version (.-version package-json)]
                      (info version backend-version)
                      (if (= version backend-version)
                        (do (put-fn [:window/new msg])
                            (put-fn (with-meta [:window/close]
                                               {:window-id loading-page})))
                        (do (kill-by-port port)
                            (try-again res))))
                    (catch :default e (error e))))]
            (.on res "data" (fn [chunk] (swap! data str chunk)))
            (.on res "end" version-handler)
            (info "HTTP response: " status-code (= status-code 200))
            (when-not (= status-code 200)
              (try-again res))))
        req (http/get (clj->js {:host "localhost"
                                :port port
                                :path "/package.json"}) res-handler)]
    (.on req "error" try-again)
    {:new-state (update-in current-state [:attempt] #(inc (or % 0)))}))

(defn start-jvm [{:keys [current-state msg-payload]}]
  (let [{:keys [user-data java jar app-path data-path
                gql-port logdir playground-path]} rt/runtime-info
        args ["-Dapple.awt.UIElement=true" "-Xmx2g" "-jar" jar]
        environment (:environment msg-payload)
        port (if (= environment :live) PORT (:pg-port rt/runtime-info))
        data-path (if (= environment :live) data-path playground-path)
        opts {:detached true
              :cwd      user-data
              :env      {:PORT      port
                         :GQL_PORT  gql-port
                         :LOG_FILE  (:logfile-jvm rt/runtime-info)
                         :LOG_DIR   logdir
                         :APP_PATH  app-path
                         :DATA_PATH data-path}}
        service (spawn-process java args opts)]
    (info "JVM: startup" environment)
    {:new-state (assoc-in current-state [:service environment] service)}))

(defn start-spotify [_]
  (info "STARTUP: start spotify")
  (let [{:keys [user-data app-path node-path]} rt/runtime-info
        spotify (spawn-process node-path
                               [(str app-path "/electron/spotify.js")]
                               {:detached true
                                :stdio    "ignore"
                                :cwd      app-path
                                :env      {:USER_DATA user-data
                                           :APP_PATH  app-path}})]
    (info "SPOTIFY spawned" spotify)
    {}))

(defn shutdown [{:keys []}]
  (info "Shutting down")
  (.quit app)
  {})

(defn open-external [{:keys [msg-payload]}]
  (let [url msg-payload]
    (when-not (str/includes? url (str "localhost:" (:port rt/runtime-info)))
      (info "Opening" url)
      (.openExternal shell url)))
  {})

(defn shutdown-jvm [{:keys [msg-payload put-fn]}]
  (let [environments (:environments msg-payload)
        {:keys [port pg-port]} rt/runtime-info]
    (when (contains? environments :live)
      (kill-by-port port))
    (when (contains? environments :playground)
      (kill-by-port pg-port)))
  (put-fn [:schedule/new {:timeout 1500 :message [:app/shutdown]}])
  {})

(defn clear-cache [{:keys []}]
  (info "Clearing Electron Cache")
  (let [session (.-defaultSession session)]
    (.clearCache session #(info "Electron Cache Cleared")))
  {})

(defn clear-iww-cache [{:keys []}]
  (info "Clearing meins cache")
  (let [cache-file (:cache rt/runtime-info)
        cache-exists? (existsSync cache-file)]
    (when cache-exists?
      (renameSync cache-file (str cache-file ".bak"))))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:jvm/start           start-jvm
                 :jvm/loaded?         jvm-up?
                 :spotify/start       start-spotify
                 :app/shutdown        shutdown
                 :wm/open-external    open-external
                 :window/resized      window-resized
                 :app/shutdown-jvm    shutdown-jvm
                 :app/clear-iww-cache clear-iww-cache
                 :app/clear-cache     clear-cache}})

(.on app "window-all-closed"
     (fn [_ev]
       (info "window-all-closed")
       (when-not (= (:platform rt/runtime-info) "darwin")
         (.quit app))))
