(ns meo.electron.renderer.screenshot
  (:require [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.helpers :as h]
            [matthiasn.systems-toolbox.component :as st]))

(defn state-fn [_put-fn]
  (let [observed (atom {})]
    {:observed observed}))

(defn screenshot [{:keys [observed put-fn msg-payload]}]
  (let [screenshot-ts (st/now)
        filename (str screenshot-ts ".png")
        entry (merge {:img_file  filename
                      :tags      #{"#screenshot" "#import"}
                      :perm_tags #{"#screenshot"}}
                     msg-payload)
        new-fn (h/new-entry put-fn entry nil)]
    (js/setTimeout new-fn 2000)
    (info "initiating screenshot" entry)
    {:emit-msg [:import/screenshot {:filename filename}]}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:screenshot/take screenshot}})

