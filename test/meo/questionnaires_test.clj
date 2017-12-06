(ns meo.questionnaires-test
  (:require [clojure.test :refer :all]
            [meo.electron.renderer.ui.questionnaires :as q]
            [meo.jvm.graph.stats.questionnaires :as sq]
            [meo.jvm.file-utils :as fu]
            [meo.store-test-common :as stc]
            [meo.store-test :as st]))

(def cfg
  {:aggregations {:pos {:type  :sum
                        :label "Positive Affect Score:"
                        :items #{1 3 5 9 10 12 14 16 17 19}}
                  :neg {:type  :sum
                        :label "Negative Affect Score:"
                        :items #{2 4 6 7 8 11 13 15 18 20}}}})

(def test-entry1
  {:questionnaires {:panas {7  3
                            20 2
                            1  1
                            4  3
                            15 4
                            13 3
                            6  3
                            17 3
                            3  3
                            12 2
                            2  2
                            19 3
                            11 4
                            9  2
                            5  4
                            14 3
                            16 4
                            10 3
                            18 3
                            8  3}}})
(def test-entry2
  {:questionnaires {:panas {7  3
                            20 2
                            1  1
                            4  3
                            15 4
                            13 3
                            6  3
                            17 3
                            3  3
                            12 2
                            2  2
                            19 3
                            11 4
                            9  2
                            5  4
                            14 3
                            16 4
                            10 3
                            18 3}}})

(deftest scores-test
  (testing "correct scores for completely filled questionnaire"
    (let [test-scores (q/scores test-entry1 [:questionnaires :panas] cfg)]
      (is (= 28 (-> test-scores :pos :score)))
      (is (= 30 (-> test-scores :neg :score)))))
  (testing "only calculates score for aggregation with all answers"
    (let [test-scores (q/scores test-entry2 [:questionnaires :panas] cfg)]
      (is (= 28 (-> test-scores :pos :score)))
      (is (nil? (:neg test-scores)))))
  (testing "returns empty map when no form data"
    (let [test-scores (q/scores {} [:questionnaires :panas] cfg)]
      (is (= {} test-scores)))))

(def stats-test-entries
  [{:mentions       #{}
    :tags           #{"#done" "#PANAS"}
    :timestamp      1450999000001
    :md             "and #done"
    :questionnaires {:panas {1  1, 2 1, 3 1, 4 1, 5 1, 6 1, 7 1, 8 1, 9 1,
                             10 1, 11 1, 12 1, 13 1, 14 1, 15 1, 16 1, 17 1,
                             18 1, 19 1, 20 1}}}
   {:mentions       #{}
    :tags           #{"#done" "#PANAS"}
    :timestamp      1450999000002
    :md             "and #done"
    :questionnaires {:panas {1  1, 2 2, 3 3, 4 4, 5 5, 6 1, 7 2, 8 3, 9 4,
                             10 5, 11 1, 12 2, 13 3, 14 4, 15 5, 16 1, 17 2,
                             18 3, 19 4, 20 5}}}
   {:mentions  #{}
    :tags      #{"#done" "#PANAS"}
    :timestamp 1450999000003
    :md        "and #done"}
   {:mentions       #{}
    :tags           #{"#done" "#PANAS"}
    :timestamp      1450999000004
    :md             "and #done"
    :questionnaires {:panas {1  1, 2 2, 3 3, 4 4, 5 5, 6 1, 7 2, 8 3, 9 4,
                             10 5, 11 1, 12 2, 13 3, 14 4, 15 5, 16 1, 17 2,
                             18 3, 19 4}}}
   {:mentions  #{}
    :tags      #{"#done"}
    :timestamp 1450999000005
    :md        "and #done"}])


(deftest questionnaire-stats-test
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path]
      (let [new-state (reduce stc/persist-reducer
                              current-state
                              stats-test-entries)]
        (testing "correct scores for filled forms"
          (let [stats (sq/questionnaires new-state)
                with-results (into {} (filter #(seq (second %)) stats))
                ]
            (is (= {:panas {1450999000001 {:neg     10
                                           :pos     10
                                           :starred nil}
                            1450999000002 {:neg     29
                                           :pos     31
                                           :starred nil}
                            1450999000003 {:starred nil}
                            1450999000004 {:pos     31
                                           :starred nil}}}
                   with-results))))))))
