(ns meo.stats-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.test :refer [deftest testing is]]
            [meo.store-test :as st]
            [meo.jvm.graph.stats.time :as gst]
            [meo.store-test-common :as stc]
            [meo.jvm.graph.add :as ga]
            [clj-time.coerce :as ctc]
            [meo.jvm.file-utils :as fu]))

(def stats-test-entries
  [{:mentions  #{}
    :tags      #{"#task"}
    :timestamp 1450999100000
    :md        "Some #task"}

   {:mentions      #{}
    :tags          #{"#task"}
    :primary-story 1484076392371
    :timestamp     1450999200000
    :md            "Some other #task"}
   {:mentions       #{}
    :tags           #{"#done"}
    :entry-type     :pomodoro
    :completed-time 291
    :planned-dur    10000
    :timestamp      1450999200001
    :comment-for    1450999200000
    :md             "and #done"}

   {:mentions      #{}
    :tags          #{"#task"}
    :timestamp     1450999000000
    :primary-story 1484076392372
    :md            "Some other #task"}
   {:mentions       #{}
    :tags           #{"#done"}
    :entry-type     :pomodoro
    :completed-time 699
    :planned-dur    -1
    :timestamp      1450999000001
    :comment-for    1450999000000
    :md             "and #done"}

   {:mentions      #{"@someone"}
    :tags          #{"#task"}
    :timestamp     1450999300000
    :primary-story 1484076392372
    :md            "Yet another #task"}
   {:mentions    #{"@someone"}
    :tags        #{"#backlog"}
    :timestamp   1450999300001
    :comment-for 1450999300000
    :md          "for #backlog"}
   {:mentions       #{}
    :tags           #{"#progress"}
    :entry-type     :pomodoro
    :completed-time 200
    :planned-dur    -1
    :timestamp      1450999300002
    :comment-for    1450999300000
    :md             "some #progress"}

   {:mentions  #{"@JaneDoe"}
    :tags      #{"#task"}
    :timestamp 1450999300010
    :md        "And yet another #task @JaneDoe"}
   {:mentions       #{"@JaneDoe"}
    :tags           #{"#closed"}
    :timestamp      1450999300011
    :entry-type     :pomodoro
    :completed-time 111
    :planned-dur    -1
    :comment-for    1450999300010
    :md             "irrelevant #closed @JaneDoe"}])

(deftest pomodoro-stats-test
  "test daily pomodoro stats"
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path
                  ga/local-dt (fn [entry] (ctc/from-long (:timestamp entry)))]
      (let [new-state (reduce stc/persist-reducer
                              current-state
                              stats-test-entries)]
        (testing
          "task summary stats are correct"
          (let [mapper (gst/time-mapper new-state)
                stats (mapper {:date-string "2015-12-24"})]
            (is (= ["2015-12-24"
                    {:date-string   "2015-12-24"
                     :time-by-saga  {:no-saga 1301}
                     :time-by-story {1484076392371 291
                                     1484076392372 899
                                     :no-story     111}
                     :time-by-ts    {1450999000001 {:comment-for 1450999000000
                                                    :completed   699
                                                    :manual      0
                                                    :saga        nil
                                                    :story       1484076392372
                                                    :summed      699
                                                    :timestamp   1450999000001}
                                     1450999200001 {:comment-for 1450999200000
                                                    :completed   291
                                                    :manual      0
                                                    :saga        nil
                                                    :story       1484076392371
                                                    :summed      291
                                                    :timestamp   1450999200001}
                                     1450999300002 {:comment-for 1450999300000
                                                    :completed   200
                                                    :manual      0
                                                    :saga        nil
                                                    :story       1484076392372
                                                    :summed      200
                                                    :timestamp   1450999300002}
                                     1450999300011 {:comment-for 1450999300010
                                                    :completed   111
                                                    :manual      0
                                                    :saga        nil
                                                    :story       :no-story
                                                    :summed      111
                                                    :timestamp   1450999300011}}
                     :total-time    1301}]
                   stats))))))))
