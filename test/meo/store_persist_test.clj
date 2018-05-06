(ns meo.store-persist-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.test :refer [deftest testing is use-fixtures]]
            [matthiasn.systems-toolbox.component :as comp]
            [meo.jvm.files :as f]
            [meo.store-test :as st]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.store-test-common :as stc]
            [meo.jvm.files :as f]
            [meo.jvm.file-utils :as fu]
            [me.raynes.fs :as fs]))

(deftest persist-test
  "Test that different queries return the expected results against app state
   thawed from appstate cache file."
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path test-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path
                  fu/app-cache-file (str test-path "/cache.dat")]
      (let [simple-query-uid (comp/make-uuid)
            simple-query2-uid (comp/make-uuid)
            no-results-query-uid (comp/make-uuid)
            tasks-query-uid (comp/make-uuid)
            tasks-done-query-uid (comp/make-uuid)
            tasks-not-done-query-uid (comp/make-uuid)

            new-state (reduce stc/persist-reducer current-state stc/test-entries)
            new-state (reduce stc/persist-reducer new-state
                              (map st/mk-test-entry (range 100)))

            _ (f/persist-state! new-state)
            thawed-state (:state (f/state-from-file))

            req-msg
            {:queries {simple-query-uid         stc/simple-query
                       simple-query2-uid        (merge stc/simple-query {:n 200})
                       tasks-query-uid          stc/tasks-query
                       no-results-query-uid     stc/no-results-query
                       tasks-done-query-uid     stc/tasks-done-query
                       tasks-not-done-query-uid stc/tasks-not-done-query}}

            res (second (:emit-msg (gq/query-fn {:current-state @thawed-state
                                                 :msg-payload   req-msg
                                                 :put-fn        (fn [_])})))]

        (testing
          "query with no matches should return 0 results"
          (is (empty? (get-in res [:entries no-results-query-uid]))))

        (testing
          "simple query has 40 results"
          (is (= 40
                 (count (get-in res [:entries simple-query-uid])))))

        (testing
          "simple query2 returns all results"
          (is (= 107
                 (count (get-in res [:entries simple-query2-uid])))))

        (testing
          "tasks query has 5 results"
          (is (= 5
                 (count (get-in res [:entries tasks-query-uid])))))

        (testing
          "tasks done query has 3 results"
          (is (= 3
                 (count (get-in res [:entries tasks-done-query-uid])))))

        (testing
          "tasks - not done query has 2 results"
          (is (= 2
                 (count (get-in res [:entries tasks-not-done-query-uid])))))

        (testing
          "hashtags and mentions in result of stats-tags publish fn"
          (let [res (gs/make-stats-tags new-state)]
            (is (= (set (:hashtags res)) #{"#task" "#entry" "#test" "#done" "#new"
                                           "#completed" "#blah" "#comment"}))
            (is (= stc/private-tags
                   (:pvt-displayed res)))
            (is (= #{"@myself" "@someone"}
                   (:mentions res)))))))))


(defn delete-appstate [f]
  (fs/delete "./test-data/cache.dat")
  (f)
  (fs/delete "./test-data/cache.dat"))

(use-fixtures :each delete-appstate)
