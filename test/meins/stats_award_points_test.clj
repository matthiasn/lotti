(ns meins.stats-award-points-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.pprint :as pp]
            [clojure.test :refer [deftest is testing]]
            [meins.jvm.graph.stats.awards :as aw]))

(def entries
  [{:habit {:completion_ts "2017-03-24T13:20:03+01:00" :done true :points 10}}
   {:habit {:completion_ts "2017-03-25T09:27:15+01:00" :done true :points 100}}
   {:habit {:completion_ts "2017-03-24T20:50:38+01:00" :done true :points 20}}
   {:habit {:completion_ts "2017-03-24T18:30:45+01:00" :done true :points 100}}
   {:habit {:completion_ts "2017-03-26T14:42:38+02:00" :done true :points 100}}
   {:habit {:completion_ts "2017-03-26T14:42:38+02:00" :done true :points 100}}
   {:habit {:completion_ts "2017-03-26T11:36:01+02:00" :done true :points 10}}
   {:habit {:completion_ts "2017-03-24T21:10:59+01:00" :done true :points 20}}
   {:habit {:completion_ts "2017-03-26T11:07:06+02:00" :done true :points 5}}
   {:habit {:completion_ts "2017-03-25T08:23:51+01:00" :done true :points 5}}
   {:habit {:completion_ts "2017-03-25T23:40:13+01:00" :done true :points 30}}
   {:habit {:completion_ts "2017-03-24T11:35:18+01:00" :done true :points 10}}
   {:habit {:completion_ts "2017-03-23T23:54:43+01:00" :done true :points 30}}
   {:habit {:completion_ts "2017-03-25T23:44:19+01:00" :done true :points 30}}
   {:habit {:completion_ts "2017-03-25T18:48:17+01:00" :done true :points 20}}
   {:habit {:completion_ts "2017-03-24T13:10:35+01:00" :done true :points 15}}
   {:habit {:completion_ts "2017-03-24T20:48:33+01:00" :done true :points 5}}
   {:habit {:completion_ts "2017-03-26T14:23:16+02:00" :done true :points 10}}
   {:habit {:completion_ts "2017-03-24T11:41:54+01:00" :done true :points 10}}])

(def entries2
  [{:habit {:completion_ts "2017-03-24T13:20:03+01:00" :done true :points 10}}
   {:habit {:completion_ts "2017-03-25T09:27:15+01:00" :done true :points 100}}
   {:habit {:completion_ts "2017-03-24T20:50:38+01:00" :done false :points 20}}])

(deftest award-point-stats-test
  (testing "works with empty stats list"
    (is (= {:by_day []
            :total  0}
           (aw/award-points-by :habit []))))
  (testing "sums correctly"
    (is (= {:by_day [{:date_string "2017-03-24"
                      :task        190}
                     {:date_string "2017-03-25"
                      :task        185}
                     {:date_string "2017-03-26"
                      :task        225}
                     {:date_string "2017-03-23"
                      :task        30}]
            :total  630}
           (aw/award-points-by :habit entries))))
  (testing "ignores entry when not done"
    (is (= {:by_day [{:date_string "2017-03-24"
                      :task        10}
                     {:date_string "2017-03-25"
                      :task        100}]
            :total  110}
           (aw/award-points-by :habit entries2)))))
