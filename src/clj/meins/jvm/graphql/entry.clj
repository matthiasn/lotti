(ns meins.jvm.graphql.entry
  (:require [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]))

(defn entry-by-ts [state context args value]
  (let [{:keys [ts]} args
        ts (Long/parseLong ts)
        current-state @state
        entry (->> (gq/get-entry current-state ts)
                   (gq/entry-w-story current-state)
                   (gc/entry-w-comments current-state)
                   (gc/linked-for current-state))]
    entry))
