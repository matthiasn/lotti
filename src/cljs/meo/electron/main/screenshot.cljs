(ns meo.electron.main.screenshot
  (:require [taoensso.timbre :refer-macros [info debug error]]
            [screenshot-desktop :as screenshot]
            [meo.electron.main.runtime :as rt]))

(defn take-screenshot [{:keys [put-fn msg-payload]}]
  (let [filename (:filename msg-payload)
        full-path (str (:img-path rt/runtime-info) "/" filename)]
    (info "taking screenshot" full-path)
    (-> (screenshot (clj->js {:filename full-path}))
        (.then (fn [full-path]
                 (info "took screenshot:" full-path)
                 (put-fn [:import/gen-thumbs {:filename  filename
                                              :full-path full-path}]))))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/screenshot take-screenshot}})
