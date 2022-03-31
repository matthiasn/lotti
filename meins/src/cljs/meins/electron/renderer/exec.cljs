(ns meins.electron.renderer.exec
  (:require [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [info]]))

(defn create-entry [{:keys [msg-payload msg-meta put-fn]}]
  (info "create entry:" msg-payload)
  (let [briefing (subscribe [:briefing])
        entry (if (:link-current-day msg-meta)
                (merge
                  {:linked_entries #{(:timestamp @briefing)}
                   :starred        true}
                  msg-payload)
                msg-payload)
        open (fn [x]
               (info x)
               (put-fn [:search/add
                        {:tab-group (or (:tab-group msg-meta) :right)
                         :query     (up/parse-search (:timestamp x))}]))
        f (h/new-entry entry open)]
    (info entry)
    (f)
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:entry/create create-entry}})
