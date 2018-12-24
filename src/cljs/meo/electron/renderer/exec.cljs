(ns meo.electron.renderer.exec
  (:require [taoensso.timbre :refer-macros [info]]
            [electron :refer [ipcRenderer]]
            [cljs.spec.alpha :as s]
            [meo.electron.renderer.helpers :as h]
            [meo.common.utils.parse :as up]))

(s/def :exec/js map?)

(defn exec-js [{:keys [current-state msg-payload]}]
  (info "EXEC:" msg-payload)
  (let [js (:js msg-payload)]
    (.eval js/window js)
    {}))

(defn create-entry [{:keys [msg-payload put-fn]}]
  (info "create entry:" msg-payload)
  (let [open (fn [x]
               (info x)
               (put-fn [:search/add
                             {:tab-group :left
                              :query     (up/parse-search (:timestamp x))}]))
        f (h/new-entry msg-payload open)]
    (f)

    {}))

(defn cmp-map [cmp-id relay-types]
  {:cmp-id      cmp-id
   :handler-map {:exec/js      exec-js
                 :entry/create create-entry}})
