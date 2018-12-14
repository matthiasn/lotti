(ns meo.electron.renderer.screenshot
  (:require [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.helpers :as h]))

(defn screenshot [{:keys [put-fn msg-payload]}]
  (let [new-fn (h/new-entry put-fn msg-payload)]
    (new-fn)
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:screenshot/save screenshot}})

