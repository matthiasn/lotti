(ns meins.electron.main.update
  (:require ["electron-log" :as electron-log]
            [electron-updater :refer [autoUpdater]]
            [taoensso.timbre :refer [error info]]))

(defn state-fn [put-fn]
  (try
    (let [state (atom {:open-window false})
          put-fn (fn [msg]
                   (let [msg-meta (merge {:window-id :broadcast} (meta msg))]
                     (put-fn (with-meta msg msg-meta))))
          no-update-available (fn [_]
                                (info "Update not available.")
                                (put-fn [:update/status {:status :update/not-available}]))
          update-available (fn [info]
                             (let [info (js->clj info :keywordize-keys true)]
                               (info "Update available.")
                               (if (:open-window @state)
                                 (put-fn [:window/updater])
                                 (put-fn [:update/status {:status :update/available
                                                          :info   info}]))))
          checking (fn [_]
                     (info "Checking for update...")
                     (put-fn [:update/status {:status :update/checking}]))
          downloaded (fn [_ev]
                       (info "Update downloaded")
                       (when (:immediate @state)
                         (put-fn [:app/shutdown-jvm {:environments #{:live :playground}}])
                         (put-fn [:schedule/new
                                  {:timeout 1000
                                   :message [:update/quit-install]}]))
                       (put-fn [:update/status {:status :update/downloaded}]))
          downloading (fn [progress]
                        (let [info (js->clj progress :keywordize-keys true)]
                          (info "Update downloading" (str info))
                          (put-fn [:update/status {:status :update/downloading
                                                   :info   info}])))
          error (fn [ev]
                  (error "in auto-updater" ev)
                  (put-fn [:update/status {:status :update/not-available}]))]
      (info "Starting UPDATE Component")
      (aset autoUpdater "autoDownload" false)
      (aset autoUpdater "logger" electron-log)
      (.on autoUpdater "checking-for-update" checking)
      (.on autoUpdater "update-available" update-available)
      (.on autoUpdater "update-not-available" no-update-available)
      (.on autoUpdater "update-downloaded" downloaded)
      (.on autoUpdater "download-progress" downloading)
      (.on autoUpdater "error" error)
      {:state state})
    (catch js/object e (error e))))

(defn check-updates [open-window]
  (fn [{:keys [current-state]}]
    (info "UPDATE: check release versions")
    (aset autoUpdater "allowPrerelease" false)
    (.checkForUpdates autoUpdater)
    {:new-state (assoc-in current-state [:open-window] open-window)}))

(defn check-updates-beta [_]
  (info "UPDATE: check beta versions")
  (aset autoUpdater "allowPrerelease" true)
  (.checkForUpdates autoUpdater)
  {})

(defn download-updates [{:keys [current-state msg-payload put-fn]}]
  (info "UPDATE: download")
  (-> (.downloadUpdate autoUpdater)
      (.then (fn [_ev]
               (info "Update downloaded")
               (put-fn [:update/status {:status :update/downloaded}]))))
  {:new-state (assoc-in current-state [:immediate] msg-payload)})

(defn install-updates [_]
  (info "UPDATE: install")
  {:emit-msg [[:app/clear-cache]
              [:app/shutdown-jvm {:environments #{:live :playground}}]
              [:schedule/new {:timeout 1000
                              :message [:update/quit-install]}]]})

(defn quit-install [_]
  (info "UPDATE: quit and install")
  (.quitAndInstall autoUpdater false)
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:update/check        (check-updates false)
                 :update/auto-check   (check-updates true)
                 :update/check-beta   check-updates-beta
                 :update/download     download-updates
                 :update/install      install-updates
                 :update/quit-install quit-install}})

