(ns meins.electron.renderer.exec
  (:require [taoensso.timbre :refer-macros [info]]
            [cljs.spec.alpha :as s]
            [meins.electron.renderer.helpers :as h]
            [meins.common.utils.parse :as up]))

(defn create-entry [{:keys [msg-payload put-fn]}]
  (info "create entry:" msg-payload)
  (let [open (fn [x]
               (info x)
               (put-fn [:search/add
                             {:tab-group :right
                              :query     (up/parse-search (:timestamp x))}]))
        f (h/new-entry msg-payload open)]
    (f)

    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:entry/create create-entry}})
