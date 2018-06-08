(ns meo.electron.main.screenshot
  (:require [taoensso.timbre :refer-macros [info debug error]]
            [screenshot-desktop :as screenshot]
            [sharp]
            [meo.electron.main.runtime :as rt]))

(defn thumbnail [full-path filename max-w-h]
  (let [thumbs-path (:thumbs-path rt/runtime-info)
        new-filename (str thumbs-path "/" max-w-h "/" filename)]
    (-> (sharp full-path)
        (.resize max-w-h)
        (.toFile new-filename (fn [err success]
                                (when err (error err))
                                (when success (info (js->clj success))))))))

(defn take-screenshot [{:keys [put-fn msg-payload]}]
  (let [filename (:filename msg-payload)
        full-path (str (:img-path rt/runtime-info) "/" filename)]
    (info "taking screenshot" full-path)
    (-> (screenshot (clj->js {:filename full-path}))
        (.then (fn [full-path]
                 (info "took screenshot:" full-path)
                 (thumbnail full-path filename 256)
                 (thumbnail full-path filename 512)
                 (thumbnail full-path filename 2048))))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/screenshot take-screenshot}})
