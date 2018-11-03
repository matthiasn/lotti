(ns meo.electron.main.menu
  (:require [taoensso.timbre :refer-macros [info]]
            [electron :refer [app Menu dialog globalShortcut]]
            [meo.electron.main.runtime :as rt]
            [clojure.walk :as walk]))

(def capabilities (:capabilities rt/runtime-info))

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
  (let [update-win {:url "electron/updater.html" :width 600 :height 300}
        check-updates #(put-fn [:window/new update-win])
        open (fn [page] (put-fn [:nav/to {:page page}]))]
    {:label   "Application"
     :submenu [(when (= (:platform rt/runtime-info) "darwin")
                 {:label    "About meo"
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
                :click #(do (put-fn [:app/shutdown-jvm {:environments #{:live :playground}}])
                            (put-fn [:app/shutdown]))}
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

(defn file-menu [put-fn]
  (let [new-entry #(put-fn [:exec/js {:js "meo.electron.renderer.ui.menu.new_entry()"}])
        new-story #(put-fn [:exec/js {:js "meo.electron.renderer.ui.menu.new_story()"}])
        new-saga #(put-fn [:exec/js {:js "meo.electron.renderer.ui.menu.new_saga()"}])]
    {:label   "File"
     :submenu [{:label       "New Entry"
                :accelerator "CmdOrCtrl+N"
                :click       new-entry}
               {:label "New Story" :click new-story}
               {:label "New Saga" :click new-saga}
               (when (contains? capabilities :sync-swift)
                 {:label       "Upload"
                  :accelerator "CmdOrCtrl+U"
                  :click       #(put-fn [:import/listen])})
               {:label   "Import"
                :submenu [{:label       "Photos"
                           :accelerator "CmdOrCtrl+I"
                           :click       #(import-dialog put-fn)}
                          (when (contains? capabilities :git-import)
                            {:label "Git repos"
                             :click #(put-fn [:import/git])})
                          (when (contains? capabilities :spotify)
                            {:label "Spotify"
                             :click #(put-fn [:import/spotify])})]}
               {:label "Export"
                :click #(put-fn [:export/geojson])}]}))

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
                :click       #(put-fn [:search/cmd {:t :close-tab}])}
               {:label       "Next Tab"
                :accelerator "Ctrl+Tab"
                :click       #(put-fn [:search/cmd {:t :next-tab}])}
               {:label       "New Window"
                :accelerator "CmdOrCtrl+Alt+N"
                :click       new-window}
               {:label "Main View"
                :click #(open :main)}
               (when (contains? capabilities :countries)
                 {:label "Countries"
                  :click #(open :countries)})
               (when (contains? capabilities :heatmap)
                 {:label "Heatmap"
                  :click #(open :heatmap)})
               (when (contains? capabilities :scatter-matrix)
                 {:label "Scatter Matrix"
                  :click #(open :correlation)})
               {:label       "Toggle Split View"
                :accelerator "CmdOrCtrl+Alt+S"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :single-column]}])}
               {:label "Toggle Private Mode"
                :click #(put-fn [:cmd/toggle-key {:path [:cfg :show-pvt]}])}
               (when (contains? capabilities :dashboard-banner)
                 {:label "Toggle Charts"
                  :click #(put-fn [:cmd/toggle-key {:path [:cfg :dashboard-banner]}])})
               {:type "separator"}
               {:role "zoomin"}
               {:role "zoomout"}
               {:type "separator"}
               {:label       "Open Dev Tools"
                :accelerator "CmdOrCtrl+Alt+I"
                :click       #(put-fn [:window/dev-tools])}]}))

(defn capture-menu [put-fn]
  (let [screenshot #(put-fn [:screenshot/take])
        accelerator (if (= (:platform rt/runtime-info) "darwin")
                      "Command+Shift+3"
                      "PrintScreen")]
    {:label   "Capture"
     :submenu [{:label       "New Screenshot"
                :accelerator accelerator
                :click       screenshot}]}))

(defn learn-menu [put-fn]
  (let [export #(put-fn [:tf/learn-stories #{:export}])
        learn #(put-fn [:tf/learn-stories #{:learn}])
        export-learn #(put-fn [:tf/learn-stories #{:export :learn}])]
    {:label   "Learn"
     :submenu [#_{:label "Export for Stories Model"
                  :click export}
               #_{:label "Train Stories Model"
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

(defn state-fn [put-fn]
  (let [put-fn (fn [msg]
                 (let [msg-meta (merge {:window-id :active} (meta msg))]
                   (put-fn (with-meta msg msg-meta))))
        menu-tpl [(app-menu put-fn)
                  (file-menu put-fn)
                  (edit-menu put-fn)
                  (view-menu put-fn)
                  (capture-menu put-fn)
                  (when (contains? capabilities :tensorflow)
                    (learn-menu put-fn))
                  (playground-menu put-fn)
                  (dev-menu put-fn)]
        menu-tpl (rm-filtered (filter identity menu-tpl))
        menu (.buildFromTemplate Menu (clj->js menu-tpl))
        activate #(put-fn [:window/activate])
        screenshot #(put-fn [:screenshot/take])]
    (info "Starting Menu Component")
    (.on app "activate" activate)
    (if (= (:platform rt/runtime-info) "darwin")
      (.register globalShortcut "Command+Shift+3" screenshot)
      (.register globalShortcut "PrintScreen" screenshot))
    (.setApplicationMenu Menu menu))
  {:state (atom {})})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
