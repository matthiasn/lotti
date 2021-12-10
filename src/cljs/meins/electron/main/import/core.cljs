(ns meins.electron.main.import.core
  (:require [taoensso.timbre :refer [error info]]
            ["fs" :refer [existsSync readFileSync writeFileSync]]
            [meins.electron.main.import.audio :as ai]
            [meins.electron.main.runtime :as rt]
            [cljs.reader :refer [read-string]]
            [meins.electron.main.import.health :as hi]
            [meins.electron.main.import.images :as ii]
            [meins.electron.main.import.measurement :as im]
            [meins.electron.main.import.survey :as is]
            [meins.electron.main.import.health :as ih]
            [meins.electron.main.import.text :as it]))

(def data-path (:data-path rt/runtime-info))
(def cfg-path (str data-path "/flutter-import-cfg.edn"))

(defn read-cfg []
  (when (existsSync cfg-path)
    (read-string (readFileSync cfg-path "utf-8"))))

(defn write-cfg [cfg]
  (writeFileSync cfg-path (pr-str cfg)))

(defn import-media [{:keys [put-fn]}]
  (let [cfg (read-cfg)
        path (:container-documents-path cfg)
        data-path (:data-path rt/runtime-info)]
    (when-not cfg (error "Flutter config does not exist"))
    (when cfg
      (info "import-images:" path)
      (ii/import-image-files path put-fn)
      (it/import-text-entries path put-fn)
      (is/import-filled-surveys path put-fn)
      (ih/import-quantitative-data path put-fn)
      (im/import-measurement-entries path data-path put-fn)
      (ai/import-audio-files path put-fn))))

(defn set-flutter-docs-path [{:keys [msg-payload]}]
  (let [path (:directory msg-payload)
        cfg {:container-documents-path path}]
    (info "writing flutter config")
    (write-cfg cfg)))

(defn cmp-map [cmp-id audio-path img-path]
  (reset! ai/audio-path-atom audio-path)
  (reset! ii/image-path-atom img-path)
  {:cmp-id      cmp-id
   :handler-map {:import/set-flutter-docs-path set-flutter-docs-path
                 :import/media                 import-media}})
