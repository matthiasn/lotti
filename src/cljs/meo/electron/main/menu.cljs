(ns meo.electron.main.menu
  (:require [taoensso.timbre :as timbre :refer-macros [info]]
            [electron :refer [app Menu dialog globalShortcut]]
            [meo.electron.main.runtime :as rt]))

(defn app-menu [put-fn]
  (let [update-win {:url "electron/updater.html" :width 600 :height 300}
        check-updates #(put-fn [:window/new update-win])]
    {:label   "Application"
     :submenu [{:label    "About meo"
                :selector "orderFrontStandardAboutPanel:"}
               {:label "Check for Updates..."
                :click check-updates}
               {:label "Start Spotify Service"
                :click #(put-fn [:spotify/start])}
               {:label "Quit Background Service"
                :click #(do (put-fn [:app/shutdown-jvm])
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
               {:label       "Upload"
                :accelerator "CmdOrCtrl+U"
                :click       #(put-fn [:import/listen])}
               {:label       "Import"
                :accelerator "CmdOrCtrl+I"
                :click       #(import-dialog put-fn)}
               {:label       "Export"
                :click       #(put-fn [:export/geojson])}]}))

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
        open (fn [loc] #(let [js (str "window.location.hash = '" loc "'")]
                          (put-fn [:exec/js {:js js}])))]
    {:label   "View"
     :submenu [{:label       "Close Window"
                :accelerator "CmdOrCtrl+W"
                :click       #(put-fn [:window/close])}
               {:label       "New Window"
                :accelerator "CmdOrCtrl+Alt+N"
                :click       new-window}
               {:label "Main View"
                :click (open "")}
               {:label "Charts"
                :click (open "charts1")}
               {:label "Config"
                :click (open "config")}
               {:label "Sync Config"
                :click (open "sync")}
               {:label "Countries"
                :click (open "countries")}
               {:label "Heatmap"
                :click (open "heatmap")}
               {:label "Dashboards"
                :click (open "dashboards/dashboard-1")}
               {:label "Scatter Matrix"
                :click (open "correlation")}
               {:label       "Toggle Split View"
                :accelerator "CmdOrCtrl+Alt+S"
                :click       #(put-fn [:cmd/toggle-key {:path [:cfg :single-column]}])}
               {:label "Toggle Planning Mode"
                :click #(put-fn [:cmd/toggle-key {:path [:cfg :planning-mode]}])}
               {:label "Toggle Calendar"
                :click #(put-fn [:cmd/toggle-key {:path [:cfg :show-calendar]}])}
               {:label "Toggle Charts"
                :click #(put-fn [:cmd/toggle-key {:path [:cfg :dashboard-banner]}])}
               {:type "separator"}
               {:role "zoomin"}
               {:role "zoomout"}
               {:type "separator"}
               {:label       "Open Dev Tools"
                :accelerator "CmdOrCtrl+Alt+I"
                :click       #(put-fn [:window/dev-tools])}]}))

(defn capture-menu [put-fn]
  (let [screenshot #(put-fn [:screenshot/take])]
    {:label   "Capture"
     :submenu [{:label       "New Screenshot"
                :accelerator "Command+Shift+3"
                :click       screenshot}]}))

(defn state-fn [put-fn]
  (let [put-fn (fn [msg]
                 (let [msg-meta (merge {:window-id :active} (meta msg))]
                   (put-fn (with-meta msg msg-meta))))
        menu-tpl [(app-menu put-fn)
                  (file-menu put-fn)
                  (edit-menu put-fn)
                  (view-menu put-fn)
                  (capture-menu put-fn)]
        menu (.buildFromTemplate Menu (clj->js menu-tpl))
        activate #(put-fn [:window/activate])
        screenshot #(put-fn [:screenshot/take])]
    (info "Starting Menu Component")
    (.on app "activate" activate)
    (.register globalShortcut "Command+Shift+3" screenshot)
    (.setApplicationMenu Menu menu))
  {:state (atom {})})

(defn cmp-map [cmp-id]
  {:cmp-id   cmp-id
   :state-fn state-fn})
