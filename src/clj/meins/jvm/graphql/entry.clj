(ns meins.jvm.graphql.entry
  (:require [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]
            [taoensso.timbre :refer [debug error info warn]]))

(defn entry-by-ts [state _context args _value]
  (let [{:keys [ts]} args
        ts (Long/parseLong ts)
        current-state @state
        entry (->> (gq/get-entry current-state ts)
                   (gq/entry-w-story current-state)
                   (gc/entry-w-comments current-state)
                   (gc/linked-for current-state))]
    entry))
