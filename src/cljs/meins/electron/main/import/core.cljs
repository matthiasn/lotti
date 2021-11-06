(ns meins.electron.main.import.core
  (:require [taoensso.timbre :refer [error info]]
            [meins.electron.main.import.audio :as ai]
            [meins.electron.main.import.health :as hi]
            [meins.electron.main.import.images :as ii]))

(defn import-media [{:keys [msg-payload put-fn]}]
  (let [path (:directory msg-payload)]
    (info "import-images:" path)
    (ii/import-image-files path put-fn)
    (ai/import-audio-files path put-fn)))

(defn cmp-map [cmp-id audio-path img-path]
  (reset! ai/audio-path-atom audio-path)
  (reset! ii/image-path-atom img-path)
  {:cmp-id      cmp-id
   :handler-map {:import/health hi/import-health
                 :import/media  import-media}})
