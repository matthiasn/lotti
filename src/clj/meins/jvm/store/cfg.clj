(ns meins.jvm.store.cfg
  (:require [taoensso.timbre :refer [info error warn]]
            [taoensso.timbre.profiling :refer [p profile]]
            [meins.common.specs]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graphql.custom-fields :as gcf]))

(defn refresh-cfg
  "Refresh configuration by reloading the config file. Attaches custom fields config from
   configuration entries."
  [{:keys [current-state put-fn]}]
  (let [cfg (fu/load-cfg)
        cf2 {:custom-fields (gcf/custom-fields-cfg current-state)}
        cfg (merge cfg cf2)]
    (put-fn [:backend-cfg/new cfg])
    {:new-state (assoc-in current-state [:cfg] cfg)}))
