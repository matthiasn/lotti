(ns meins.electron.renderer.screenshot
  (:require [meins.electron.renderer.helpers :as h]
            [taoensso.timbre :refer [debug info]]))

(defn screenshot [{:keys [msg-payload]}]
  (let [new-fn (h/new-entry msg-payload)]
    (new-fn)
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:screenshot/save screenshot}})

