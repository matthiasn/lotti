(ns meins.store-query-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.test :refer [deftest is testing]]
            [matthiasn.systems-toolbox.component :as comp]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.stats :as gs]
            [meins.store-test :as st]
            [meins.store-test-common :as stc]))

(deftest query-test
  "Test that different queries return the expected results."
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path test-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path]
      (let [simple-query-uid (comp/make-uuid)
            simple-query2-uid (comp/make-uuid)
            no-results-query-uid (comp/make-uuid)
            tasks-query-uid (comp/make-uuid)
            tasks-done-query-uid (comp/make-uuid)
            tasks-not-done-query-uid (comp/make-uuid)

            new-state (reduce stc/persist-reducer current-state stc/test-entries)
            new-state (reduce stc/persist-reducer new-state
                              (map st/mk-test-entry (range 100)))

            req-msg
            {:queries {simple-query-uid         stc/simple-query
                       simple-query2-uid        (merge stc/simple-query {:n 200})
                       tasks-query-uid          stc/tasks-query
                       no-results-query-uid     stc/no-results-query
                       tasks-done-query-uid     stc/tasks-done-query
                       tasks-not-done-query-uid stc/tasks-not-done-query}}

            res (second (:emit-msg (gq/query-fn {:current-state new-state
                                                 :msg-payload   req-msg
                                                 :put-fn        (fn [_])})))]

        (testing
          "query with no matches should return 0 results"
          (is (empty? (get-in res [:entries no-results-query-uid]))))

        (testing
          "hashtags and mentions in result of stats-tags publish fn"
          (let [res (gs/make-stats-tags new-state)]
            (is (= #{["#blah" 101]
                     ["#comment" 2]
                     ["#completed" 3]
                     ["#done" 4]
                     ["#entry" 101]
                     ["#new" 101]
                     ["#task" 6]
                     ["#test" 101]}
                   (set (:hashtags res))))
            (is (= stc/private-tags
                   (:pvt-displayed res)))
            (is (= #{"@myself" "@someone"}
                   (:mentions res)))))))))