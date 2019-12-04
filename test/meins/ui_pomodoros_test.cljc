(ns meins.ui-pomodoros-test
  "Here, we test the pomodoro UI functions. These tests are written in cljc and
   can also run on the JVM, as we only have pure functions in the target
    namespace."
  (:require #?(:clj [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
                    [meins.electron.renderer.ui.pomodoro :as p]))

(def test-entries
  [{:timestamp 12345}
   {:timestamp      12346
    :entry_type     :pomodoro
    :planned_dur    1500
    :completed_time 1000}
   {:timestamp      12347
    :entry_type     :pomodoro
    :planned_dur    1500
    :completed_time 1500}
   {:timestamp      12348
    :entry_type     :pomodoro
    :planned_dur    1500
    :completed_time 1500}
   {:timestamp      12349
    :entry_type     :pomodoro
    :planned_dur    1500
    :completed_time 1500}
   {:timestamp      12350
    :entry_type     :pomodoro
    :planned_dur    1500
    :completed_time 1000}])

(deftest pomodoro-stats-test
  "Test that the pomodoro-stats properly summarizes pomodoro stats."
  (testing "works on empty seq of entries"
    (is (= (p/pomodoro-stats []) {:pomodoros           0
                                  :completed_pomodoros 0
                                  :total_time          0})))

  (testing "works on test entries"
    (is (= (p/pomodoro-stats (take 4 test-entries))
           {:pomodoros           3
            :completed_pomodoros 2
            :total_time          4000})))

  (testing "works on test entries with interruptions"
    (is (= (p/pomodoro-stats test-entries)
           {:pomodoros           5
            :completed_pomodoros 3
            :total_time          6500}))))

(def empty-test-entry
  {:mentions   #{}
   :tags       #{"#cljc"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :timestamp  1465059173965
   :md         "Moving to #cljc"})

(def test-entry
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry_type     :pomodoro
   :planned_dur    1500
   :comment-for    1465059139281
   :completed_time 0
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry2
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry_type     :pomodoro
   :planned_dur    1500
   :comment-for    1465059139281
   :completed_time 100
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry2a
  {:mentions         #{}
   :tags             #{"#cljc"}
   :timezone         "Europe/Berlin"
   :utc-offset       -120
   :entry_type       :pomodoro
   :pomodoro-running true
   :planned_dur      1500
   :comment-for      1465059139281
   :completed_time   100
   :timestamp        1465059173965
   :md               "Moving to #cljc"})

(def test-entry3
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry_type     :pomodoro
   :planned_dur    1500
   :comment-for    1465059139281
   :completed_time 1500
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry3a
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry_type     :pomodoro
   :planned_dur    1500
   :comment-for    1465059139281
   :completed_time 1500
   :timestamp      1465059173965
   :md             "Moving to #cljc"})
