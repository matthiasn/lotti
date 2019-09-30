(ns meins.jvm.store.cfg
  (:require [meins.common.specs]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graphql.custom-fields :as gcf]
            [taoensso.timbre :refer [error info warn]]))

(defn refresh-cfg
  "Refresh configuration by reloading the config file.
   Attaches custom fields config from configuration entries."
  [{:keys [current-state]}]
  (let [cfg (merge
              (fu/load-cfg)
              {:custom-fields (gcf/custom-fields-cfg current-state)})]
    {:new-state (assoc-in current-state [:cfg] cfg)
     :emit-msg  [:backend-cfg/new cfg]}))
