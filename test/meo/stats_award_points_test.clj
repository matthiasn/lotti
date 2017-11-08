(ns meo.stats-award-points-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.test :refer [deftest testing is]]
            [meo.jvm.graph.stats.awards :as aw]
            [clojure.pprint :as pp]))

(def entries
  [{:habit {:completion-ts "2017-03-24T13:20:03+01:00" :done true :points 10}}
   {:habit {:completion-ts "2017-03-25T09:27:15+01:00" :done true :points 100}}
   {:habit {:completion-ts "2017-03-24T20:50:38+01:00" :done true :points 20}}
   {:habit {:completion-ts "2017-03-24T18:30:45+01:00" :done true :points 100}}
   {:habit {:completion-ts "2017-03-26T14:42:38+02:00" :done true :points 100}}
   {:habit {:completion-ts "2017-03-26T14:42:38+02:00" :done true :points 100}}
   {:habit {:completion-ts "2017-03-26T11:36:01+02:00" :done true :points 10}}
   {:habit {:completion-ts "2017-03-24T21:10:59+01:00" :done true :points 20}}
   {:habit {:completion-ts "2017-03-26T11:07:06+02:00" :done true :points 5}}
   {:habit {:completion-ts "2017-03-25T08:23:51+01:00" :done true :points 5}}
   {:habit {:completion-ts "2017-03-25T23:40:13+01:00" :done true :points 30}}
   {:habit {:completion-ts "2017-03-24T11:35:18+01:00" :done true :points 10}}
   {:habit {:completion-ts "2017-03-23T23:54:43+01:00" :done true :points 30}}
   {:habit {:completion-ts "2017-03-25T23:44:19+01:00" :done true :points 30}}
   {:habit {:completion-ts "2017-03-25T18:48:17+01:00" :done true :points 20}}
   {:habit {:completion-ts "2017-03-24T13:10:35+01:00" :done true :points 15}}
   {:habit {:completion-ts "2017-03-24T20:48:33+01:00" :done true :points 5}}
   {:habit {:completion-ts "2017-03-26T14:23:16+02:00" :done true :points 10}}
   {:habit {:completion-ts "2017-03-24T11:41:54+01:00" :done true :points 10}}])

(def entries2
  [{:habit {:completion-ts "2017-03-24T13:20:03+01:00" :done true :points 10}}
   {:habit {:completion-ts "2017-03-25T09:27:15+01:00" :done true :points 100}}
   {:habit {:completion-ts "2017-03-24T20:50:38+01:00" :done false :points 20}}])

(deftest award-point-stats-test
  (testing "works with empty stats list"
    (is (= {:total         0
            :total-skipped 0}
           (aw/award-points-by :habit {} []))))
  (testing "sums correctly"
    (is (= {:by-day        {"2017-03-23" {:habit 30}
                            "2017-03-24" {:habit 190}
                            "2017-03-25" {:habit 185}
                            "2017-03-26" {:habit 225}}
            :total         630
            :total-skipped 0}
           (aw/award-points-by :habit {} entries))))
  (testing "ignores entry when not done"
    (is (= {:by-day        {"2017-03-24" {:habit 10}
                            "2017-03-25" {:habit 100}}
            :total         110
            :total-skipped 0}
           (aw/award-points-by :habit {} entries2)))))
