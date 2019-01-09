(ns meins.electron.main.screenshot
  (:require [taoensso.timbre :refer-macros [info debug error]]
            [matthiasn.systems-toolbox.component :as st]
            [screenshot-desktop :as screenshot]
            [meins.electron.main.runtime :as rt]
            [meins.common.utils.misc :as m]
            [fs :refer [writeFile]]))

(defn take-screenshot [{:keys [put-fn]}]
  (let [ts (st/now)
        screenshot-all (aget screenshot "all")
        img-path (:img-path rt/runtime-info)]
    (-> (screenshot-all)
        (.then
          (fn [imgs]
            (doseq [[i buf] (m/idxd imgs)]
              (let [ts (+ ts i)
                    filename (str ts ".png")
                    file (str img-path "/" filename)
                    entry {:img_file  filename
                           :timestamp ts
                           :tags      #{"#screenshot" "#import"}
                           :perm_tags #{"#screenshot"}
                           :md        ""}
                    cb (fn [err]
                         (if err
                           (error "writing file" err)
                           (do (info file "saved")
                               (put-fn [:import/gen-thumbs
                                        {:filename  filename
                                         :full-path file}])
                               (put-fn [:screenshot/save entry]))))]
                (writeFile file buf "binary" cb)))))
        (.catch (fn [err] (error err))))
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:screenshot/take take-screenshot}})
