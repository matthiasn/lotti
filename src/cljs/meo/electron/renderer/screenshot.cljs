(ns meo.electron.renderer.screenshot
  (:require [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.helpers :as h]))

(defn screenshot [{:keys [msg-payload]}]
  (let [new-fn (h/new-entry msg-payload)]
    (new-fn)
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:screenshot/save screenshot}})

