(ns meins.electron.main.menu
  (:require [clojure.walk :as walk]
            [electron :refer [app dialog globalShortcut Menu shell]]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :refer [debug info]]))

(def capabilities (:capabilities rt/runtime-info))
(def platform (:platform rt/runtime-info))

(def screenshot-accelerator
  (if (= platform "darwin")
    "Command+Shift+3"
    "PrintScreen"))

(defn rm-filtered [m]
  (walk/postwalk (fn [node]
                   (if (map? node)
                     (into {}
                           (map (fn [[k v]]
                                  (if
                                    (and v (= :submenu k))
                                    [k (filter identity v)]
                                    [k v]))
                                node))
                     node))
                 m))

(defn app-menu [put-fn]
  (let [check-updates #(put-fn [:update/check])
        open (fn [page] (put-fn [:nav/to {:page   page
                                          :toggle :main}]))]
    {:label   "Application"
     :submenu [(when (= platform "darwin")
                 {:label    "About meins"
                  :selector "orderFrontStandardAboutPanel:"})
               {:label "Check for Updates..."
                :click check-updates}
               {:type "separator"}
               {:label       "Preferences"
                :accelerator "Cmd+,"
                :click       #(open :config)}
               {:type "separator"}
               (when (contains? capabilities :spotify)
                 {:label "Start Spotify Service"
                  :click #(put-fn [:spotify/start])})
               {:label "Quit Background Service"
                :click #(put-fn [:app/shutdown-jvm {:environments #{:live :playground}}])}
               {:label       "Quit"
                :accelerator "CmdOrCtrl+Q"
                :click       #(put-fn [:app/shutdown])}]}))

(defn import-dialog [put-fn]
  (let [options (clj->js {:properties  ["openFile" "multiSelections"]
                          :buttonLabel "Import"
                          :filters     [{:name       "Images"
                                         :extensions ["jpg" "png"]}]})
        callback (fn [res]
                   (let [files (js->clj res)]
                     (info files)
                     (put-fn [:import/photos files])))]
    (.showOpenDialog dialog options callback)))

(defn flutter-path-dialog [put-fn]
  (let [options (clj->js {:properties  ["openDirectory"]
                          :buttonLabel "Select Container Documents Path"})
        selected-dir (first (js->clj (.showOpenDialogSync dialog options)))]
    (put-fn [:import/set-flutter-docs-path {:directory selected-dir}])))

(defn file-menu [put-fn]
  (let [new-entry #(put-fn [:entry/create {}])
        new-task #(put-fn (with-meta
                            [:entry/create {:starred   true
                                            :perm_tags #{"#task"}}]
                            {:tab-group        :left
                             :link-current-day true}))
        new-story #(put-fn [:entry/create {:entry_type :story}])
        new-saga #(put-fn [:entry/create {:entry_type :saga}])
        new-habit #(put-fn [:entry/create {:entry_type :habit}])
        new-problem #(put-fn (with-meta
                               [:entry/create {:entry_type :problem
                                               :perm_tags  #{"#problem"}}]
                               {:tab-group :left}))
        new-custom-field #(put-fn [:entry/create
                                   {:entry_type :custom-field-cfg
                                    :perm_tags  #{"#custom-field-cfg"}
                                    :tags       #{"#custom-field-cfg"}}])
        new-dashboard #(put-fn [:entry/create
                                {:entry_type :dashboard-cfg
                                 :perm_tags  #{"#dashboard-cfg"}}])
        new-album #(put-fn [:entry/create {:perm_tags #{"#album"}}])]
    {:label   "File"
     :submenu [{:label       "New Entry"
                :accelerator "CmdOrCtrl+N"
                :click       new-entry}

               {:label   "New..."
                :submenu [{:label       "Task"
                           :click       new-task
                           :accelerator "CmdOrCtrl+T"}
                          {:label "Story"
                           :click new-story}
                          {:label "Saga"
                           :click new-saga}
                          {:label "Problem"
                           :click new-problem}
                          {:label "Habit"
                           :click new-habit}
                          {:label "Album"
                           :click new-album}
                          {:label "Dashboard"
                           :click new-dashboard}
                          {:label "Custom Field"
                           :click new-custom-field}]}
               {:label   "Import..."
                :submenu [{:label       "Photos"
                           :accelerator "CmdOrCtrl+I"
                           :click       #(import-dialog put-fn)}
                          {:label "Set Flutter Documents Path"
                           :click #(flutter-path-dialog put-fn)}
                          {:label "Entries from Flutter app"
                           :click #(put-fn [:import/media])}
                          (when (contains? capabilities :git-import)
                            {:label "Git repos"
                             :click #(put-fn [:import/git])})
                          (when (contains? capabilities :spotify)
                            {:label "Spotify Most Listened"
                             :click #(put-fn [:import/spotify])})]}
               {:label   "Export..."
                :submenu [{:label "GeoJSON"
                           :click #(put-fn [:export/geojson])}]}]}))

(defn broadcast [msg] (with-meta msg {:window-id :broadcast}))

(defn edit-menu [put-fn]
  (let [lang (fn [cc label]
               {:click #(put-fn (broadcast [:spellcheck/lang cc]))
                :label label})
        no-spellcheck #(put-fn (broadcast [:spellcheck/off]))]
    {:label   "Edit"
     :submenu [{:label       "Undo"
                :accelerator "CmdOrCtrl+Z"
                :selector    "undo:"}
               {:label       "Redo"
                :accelerator "Shift+CmdOrCtrl+Z"
                :selector    "redo:"}
               {:label       "Cut"
                :accelerator "CmdOrCtrl+X"
                :selector    "cut:"}
               {:label       "Copy"
                :accelerator "CmdOrCtrl+C"
                :selector    "copy:"}
               {:label       "Paste"
                :accelerator "CmdOrCtrl+V"
                :selector    "paste:"}
               {:label       "Select All"
                :accelerator "CmdOrCtrl+A"
                :selector    "selectAll:"}
               {:label   "Spelling"
                :submenu [(lang "en-US" "English")
                          (lang "fr-FR" "French")
                          (lang "de-DE" "German")
                          (lang "it-IT" "Italian")
                          (lang "es-ES" "Spanish")
                          {:type "separator"}
                          {:label "OFF"
                           :click no-spellcheck}]}]}))

(defn view-menu [put-fn]
  (let [index-page (:index-page rt/runtime-info)
        new-window #(put-fn [:window/new {:url index-page}])
        open (fn [page] (put-fn [:nav/to {:page page}]))]
    {:label   "View"
     :submenu [{:label       "Close Tab"
                :accelerator "CmdOrCtrl+W"
                :click       #(do (put-fn [:search/cmd {:t :close-tab}])
                                  (put-fn (with-meta [:window/close] {:window-id :help})))}
               {:label       "Next Tab"
                :accelerator "Ctrl+Tab"
                :click       #(put-fn [:search/cmd {:t :next-tab}])}
               {:label       "New Window"
                :accelerator "CmdOrCtrl+Alt+N"
                :click       new-window}
               {:label       "Back to Main View"
                :accelerator "Escape"
                :click       #(open :main)}
               {:label       "Focus Mode"
                :accelerator "CmdOrCtrl+F"
                :click       #(open :focus)}
               {:label "Post Mortems"
                :click #(open :post-mortem)}
               (when (contains? capabilities :countries)
                 {:label "Countries"
                  :click #(open :countries)})
               (when (contains? capabilities :heatmap)
                 {:label "Heatmap"
                  :click #(open :heatmap)})
               (when (contains? capabilities :locations-map)
                 {:label       "Locations Map"
                  :accelerator "CmdOrCtrl+Shift+M"
                  :click       #(open :locations-map)})
               {:label "Spotify"
                :click #(open :spotify)}
               (when (contains? capabilities :scatter-matrix)
                 {:label "Scatter Matrix"
                  :click #(open :correlation)})
               {:label       "Toggle Split View"
                :accelerator "CmdOrCtrl+Shift+S"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :single-column]}])}
               {:label       "Toggle Private Mode"
                :accelerator "CmdOrCtrl+Shift+P"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :show-pvt]}])}
               {:label       "Toggle Hidden Entries"
                :accelerator "CmdOrCtrl+Shift+P"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :show-hidden]}])}
               {:label       "Toggle Dashboard"
                :accelerator "CmdOrCtrl+Shift+D"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :dashboard-banner]}])}
               {:label "Toggle Satellite View"
                :click #(put-fn [:cmd/toggle-key {:path [:cfg :satellite-view]}])}
               {:type "separator"}
               {:role "zoomin"}
               {:role "zoomout"}
               {:type "separator"}
               {:label       "Open Dev Tools"
                :accelerator "CmdOrCtrl+Alt+I"
                :click       #(put-fn [:window/dev-tools])}]}))

(defn capture-menu [cmp-state put-fn]
  (let [screenshot #(put-fn [:screenshot/take])
        reload #(put-fn [:schedule/new
                         {:message [:menu/reload]
                          :timeout 1}])
        register #(do (.register globalShortcut screenshot-accelerator screenshot)
                      (swap! cmp-state assoc :global-screenshots true)
                      (reload))
        unregister #(do (.unregister globalShortcut screenshot-accelerator)
                        (swap! cmp-state assoc :global-screenshots false)
                        (reload))]
    {:label   "Capture"
     :submenu [{:label       "New Screenshot"
                :accelerator screenshot-accelerator
                :click       screenshot}
               (if (:global-screenshots @cmp-state)
                 {:label "Unregister Global Screenshots"
                  :click unregister}
                 {:label "Register Global Screenshots"
                  :click register})]}))

(defn learn-menu [put-fn]
  (let [export #(put-fn [:tf/learn-stories #{:export}])
        learn #(put-fn [:tf/learn-stories #{:learn}])
        export-learn #(put-fn [:tf/learn-stories #{:export :learn}])]
    {:label   "Learn"
     :submenu [{:label "Export for Stories Model"
                :click export}
               {:label "Train Stories Model"
                :click learn}
               {:label "Export and Train"
                :click export-learn}]}))

(defn playground-menu [put-fn]
  (let [index-page (:index-page-pg rt/runtime-info)
        icon (:icon-path rt/runtime-info)
        new-window #(put-fn [:window/new {:url       index-page
                                          :window-id index-page
                                          :opts      {:titleBarStyle "hidden"
                                                      :icon          icon}}])
        start #(put-fn [:jvm/loaded? {:environment :playground}])
        kill-jvm #(do (put-fn [:app/shutdown-jvm {:environments #{:playground}}])
                      (put-fn (with-meta [:window/close] {:window-id index-page})))
        gen-entries #(put-fn [:playground/gen])]
    {:label   "Playground"
     :submenu [{:label "Start Playground Environment"
                :click start}
               {:label "Stop Playground Environment"
                :click kill-jvm}
               {:label "Generate Playground Entries"
                :click gen-entries}
               {:type "separator"}
               {:label "New Playground Window"
                :click new-window}]}))

(defn dev-menu [put-fn]
  {:label   "Dev"
   :submenu [{:label "Start GraphQL Endpoint"
              :click #(put-fn [:gql/cmd {:cmd :start}])}
             {:label "Stop GraphQL Endpoint"
              :click #(put-fn [:gql/cmd {:cmd :stop}])}
             {:type "separator"}
             {:label "Start Firehose"
              :click #(put-fn [:firehose/cmd {:cmd :start}])}
             {:label "Stop Firehose"
              :click #(put-fn [:firehose/cmd {:cmd :stop}])}
             {:type "separator"}
             {:label "Persist State"
              :click #(put-fn [:state/persist])}
             {:type "separator"}
             {:label       "Toggle Data Explorer"
              :accelerator "CmdOrCtrl+D"
              :click       #(put-fn [:cmd/toggle-key {:path [:cfg :data-explorer]}])}
             {:type "separator"}
             {:label       "Open Dev Tools"
              :accelerator "CmdOrCtrl+Alt+I"
              :click       #(put-fn [:window/dev-tools])}]})

(defn help-menu [_put-fn]
  (let [help-page "https://meins.readthedocs.io/en/latest/"
        open-help #(.openExternal shell help-page)]
    {:label   "Help"
     :submenu [{:label       "Show Manual"
                :accelerator "CmdOrCtrl+?"
                :click       open-help}]}))

(defn menu [{:keys [cmp-state put-fn]}]
  (let [put-fn (fn [msg]
                 (let [msg-meta (merge {:window-id :active} (meta msg))]
                   (put-fn (with-meta msg msg-meta))))
        menu-tpl [(app-menu put-fn)
                  (file-menu put-fn)
                  (edit-menu put-fn)
                  (view-menu put-fn)
                  (capture-menu cmp-state put-fn)
                  (when (contains? capabilities :tensorflow)
                    (learn-menu put-fn))
                  (playground-menu put-fn)
                  (dev-menu put-fn)
                  (help-menu put-fn)]
        menu-tpl (rm-filtered (filter identity menu-tpl))
        menu (.buildFromTemplate Menu (clj->js menu-tpl))]
    (info "Starting Menu")
    (.setApplicationMenu Menu menu))
  {})

(defn state-fn [put-fn]
  (let [state (atom {:global-screenshots true})
        put-fn (fn [msg]
                 (let [msg-meta (merge {:window-id :active} (meta msg))]
                   (put-fn (with-meta msg msg-meta))))
        activate #(put-fn [:window/activate])
        screenshot #(put-fn [:screenshot/take])]
    (info "Starting Menu Component")
    (menu {:cmp-state state :put-fn put-fn})
    (.on app "activate" activate)
    (.register globalShortcut screenshot-accelerator screenshot)
    {:state state}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:menu/reload menu}})
