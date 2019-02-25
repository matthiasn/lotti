(ns meins.jvm.graphql.tab-search
  (:require [meins.jvm.datetime :as dt]
            [meins.common.utils.parse :as p]
            [taoensso.timbre :refer [info error warn debug]]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]
            [clojure.set :as set]
            [meins.common.utils.misc :as um]))

(defn res-diff [prev res]
  (let [prev (set prev)
        res (set res)
        diff (set/difference res prev)
        only-in-prev (set/difference prev res)
        del-ts (set (map :timestamp only-in-prev))]
    {:res diff
     :del del-ts}))

(defn tab-search [put-fn]
  (fn [state context args value]
    (let [{:keys [query n pvt story starred flagged from to]} args
          current-state @state
          from (if from (dt/ymd-to-ts from) 0)
          to (if to (+ (dt/ymd-to-ts to) (* 24 60 60 1000)) Long/MAX_VALUE)
          g (:graph current-state)
          q (merge (update-in (p/parse-search query) [:n] #(or n %))
                   {:story   (when story (Long/parseLong story))
                    :starred starred
                    :flagged flagged
                    :pvt     pvt})
          res (->> (gq/get-filtered-lazy current-state q)
                   (filter #(not (:comment_for %)))
                   (map (partial gq/entry-w-story current-state))
                   (map (partial gc/entry-w-comments current-state))
                   (map (partial gc/linked-for current-state))
                   (map #(assoc % :linked_cnt (count (:linked_entries_list %))))
                   (filter :timestamp)
                   (filter #(< (:timestamp %) to))
                   (filter #(> (:timestamp %) from))
                   (take (or n 100)))
          pvt-filter (um/pvt-filter (:options current-state))
          res (if pvt
                res
                (filter pvt-filter res))]
      res)))