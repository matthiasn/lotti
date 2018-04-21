(ns meo.store-query-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.test :refer [deftest testing is]]
            [matthiasn.systems-toolbox.component :as comp]
            [meo.store-test :as st]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.store-test-common :as stc]
            [meo.jvm.file-utils :as fu]))

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
          "stats show expected numbers"
          (let [res (gs/get-basic-stats new-state)]
            (is (= 107
                   (:entry-count res)))))

        (testing
          "hashtags and mentions in result of stats-tags publish fn"
          (let [res (gs/make-stats-tags new-state)]
            (is (= (set (:hashtags res)) #{"#task" "#entry" "#test" "#done" "#new"
                                           "#completed" "#blah" "#comment"}))
            (is (= stc/private-tags
                   (:pvt-displayed res)))
            (is (= #{"@myself" "@someone"}
                   (:mentions res)))))))))

(deftest query-test2
  "Test that different queries return the expected results."
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path
                  comp/now (fn [] 1485107134358)]
      (let [new-state (reduce stc/persist-reducer current-state stc/test-entries)
            req-msg {:queries {"query1" stc/tasks-done-query
                               "query2" stc/tasks-not-done-query}}
            res (second (:emit-msg (gq/query-fn {:current-state new-state
                                                 :msg-payload   req-msg
                                                 :put-fn        (fn [_])})))]
        (testing
          "all expected entries are fetched"
          (is (= {:entries       {"query1" [1450998400000
                                            1450998300000
                                            1450998200000]
                                  "query2" [1450998100000
                                            1450998000000]}
                  :story-predict {}
                  :entries-map   {1450998000000 {:comments            []
                                                 :last-saved          1485107134358
                                                 :linked-entries-list []
                                                 :md                  "Some #task"
                                                 :mentions            #{}
                                                 :tags                #{"#task"}
                                                 :timestamp           1450998000000}
                                  1450998100000 {:comments            []
                                                 :last-saved          1485107134358
                                                 :linked-entries-list []
                                                 :md                  "Some other #task"
                                                 :mentions            #{}
                                                 :tags                #{"#task"}
                                                 :timestamp           1450998100000}
                                  1450998200000 {:comments            []
                                                 :last-saved          1485107134358
                                                 :linked-entries-list []
                                                 :md                  "Some other #task #done"
                                                 :mentions            #{}
                                                 :tags                #{"#done"
                                                                        "#task"}
                                                 :timestamp           1450998200000}
                                  1450998300000 {:comments            [1450998300001]
                                                 :last-saved          1485107134358
                                                 :linked-entries-list []
                                                 :md                  "Yet another completed #task - #done"
                                                 :mentions            #{}
                                                 :tags                #{"#completed"
                                                                        "#done"
                                                                        "#task"}
                                                 :timestamp           1450998300000}
                                  1450998300001 {:mentions    #{}
                                                 :last-saved  1485107134358
                                                 :tags        #{"#comment"}
                                                 :timestamp   1450998300001
                                                 :comment-for 1450998300000
                                                 :md          "Some #comment"}
                                  1450998400000 {:comments            []
                                                 :last-saved          1485107134358
                                                 :linked-entries-list []
                                                 :md                  "And yet another completed #task - #done"
                                                 :mentions            #{}
                                                 :tags                #{"#completed"
                                                                        "#done"
                                                                        "#task"}
                                                 :timestamp           1450998400000}}}
                 (-> res
                     (update-in [:entries-map] #(into {} (map (fn [[k v]]
                                                                [k (dissoc v :id :vclock)])
                                                              %)))
                     (dissoc :duration-ms)))))))))
