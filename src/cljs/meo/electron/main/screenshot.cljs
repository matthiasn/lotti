(ns meo.electron.main.screenshot
  (:require [taoensso.timbre :refer-macros [info debug error]]
            [screenshot-desktop :as screenshot]
            [meo.electron.main.runtime :as rt]
            [fs :refer [writeFile]]
            [meo.common.utils.misc :as m]))

(defn take-screenshot [{:keys [put-fn msg-payload]}]
  (let [filename (:filename msg-payload)
        ts (:timestamp msg-payload)
        screenshot-all (aget screenshot "all")
        img-path (:img-path rt/runtime-info)]
    (-> (screenshot-all)
        (.then
          (fn [imgs]
            (doseq [[i buf] (m/idxd imgs)]
              (let [file (str img-path "/" (+ ts i) ".png")
                    cb (fn [err]
                         (if err
                           (error "writing file" err)
                           (do (info file "saved")
                               (put-fn [:import/gen-thumbs
                                        {:filename  filename
                                         :full-path file}]))))]
                (writeFile file buf "binary" cb)))))
        (.catch (fn [err] (error err))))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/screenshot take-screenshot}})
