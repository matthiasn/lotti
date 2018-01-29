(ns meo.electron.renderer.exec
  (:require [taoensso.timbre :refer-macros [info]]
            [electron :refer [ipcRenderer]]
            [cljs.spec.alpha :as s]))

(s/def :exec/js map?)

(defn exec-js [{:keys [current-state msg-payload]}]
  (info "EXEC:" msg-payload)
  (let [js (:js msg-payload)]
    (.eval js/window js)
    {}))

(defn cmp-map [cmp-id relay-types]
  {:cmp-id      cmp-id
   :handler-map {:exec/js exec-js}})
