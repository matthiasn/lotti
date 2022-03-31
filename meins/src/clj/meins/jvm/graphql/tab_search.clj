(ns meins.jvm.graphql.tab-search
  (:require [clojure.set :as set]
            [meins.common.utils.misc :as um]
            [meins.common.utils.parse :as p]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graphql.common :as gc]
            [taoensso.timbre :refer [debug error info warn]]))

(defn res-diff [prev res]
  (let [prev (set prev)
        res (set res)
        diff (set/difference res prev)
        only-in-prev (set/difference prev res)
        del-ts (set (map :timestamp only-in-prev))]
    {:res diff
     :del del-ts}))

(defn tab-search
  [put-fn]
  (fn [state context args _value]
    (let [{:keys [query n pvt story tab incremental starred flagged from to] :as m} args
          msg-meta (:msg-meta context)
          msg-meta (assoc msg-meta :sente-uid :broadcast)
          current-state @state
          from (if from (dt/ymd-to-ts from) 0)
          to (if to (+ (dt/ymd-to-ts to) (* 24 60 60 1000)) Long/MAX_VALUE)
          global-vclock (:global-vclock current-state)
          tab (keyword tab)
          prev (get-in current-state [:prev tab :res])
          prev-lazy-res (get-in current-state [:prev tab :lazy-res])
          prev-query (get-in current-state [:prev tab :query])
          prev-vclock (get-in current-state [:prev tab :prev-vclock])
          q (merge (update-in (p/parse-search query) [:n] #(or n %))
                   {:story   (when story (Long/parseLong story))
                    :starred starred
                    :flagged flagged
                    :pvt     pvt})
          lazy-res (if (and incremental
                            prev-lazy-res
                            (= prev-query (dissoc q :n))
                            (= global-vclock prev-vclock))
                     prev-lazy-res
                     (->> (gq/get-filtered-lazy current-state q)
                          (filter #(not (:comment_for %)))
                          (map (partial gq/entry-w-story current-state))
                          (map (partial gc/entry-w-comments current-state))
                          (map (partial gc/linked-for current-state))
                          (map #(assoc % :linked_cnt (count (:linked_entries_list %))))))
          ts-cmp (fn [f k x c] (when (k x) (f (k x) c)))
          res (->> lazy-res
                   (filter :timestamp)
                   (filter #(or (ts-cmp < :timestamp % to) (ts-cmp < :adjusted_ts % to)))
                   (filter #(or (ts-cmp > :timestamp % from) (ts-cmp > :adjusted_ts % from)))
                   (take (or n 100)))
          pvt-filter (um/pvt-filter (:options current-state))
          res (if pvt
                res
                (filter pvt-filter res))]
      (swap! state assoc-in [:prev tab] {:res         res
                                         :lazy-res    lazy-res
                                         :prev-vclock global-vclock
                                         :query       (dissoc q :n)})
      (if incremental
        (let [diff (res-diff prev res)
              diff-res (merge diff {:tab tab :query m :n n :incremental true})]
          (when (seq (set/union (:res diff) (:del diff)))
            (put-fn (with-meta [:gql/res2 diff-res] msg-meta))))
        (let [res {:res res :del #{} :tab tab :query m :n n :incremental false}]
          (put-fn (with-meta [:gql/res2 res] msg-meta))))
      res)))
