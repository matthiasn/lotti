(ns meo.ui-pomodoros-test
  "Here, we test the pomodoro UI functions. These tests are written in cljc and
   can also run on the JVM, as we only have pure functions in the target
    namespace."
  (:require #?(:clj [clojure.test :refer [deftest testing is]]
               :cljs [cljs.test :refer-macros [deftest testing is]])
                    [meo.electron.renderer.ui.pomodoro :as p]))

(def test-entries
  [{:timestamp 12345}
   {:timestamp      12346
    :entry-type     :pomodoro
    :planned-dur    1500
    :completed-time 1000}
   {:timestamp      12347
    :entry-type     :pomodoro
    :planned-dur    1500
    :completed-time 1500}
   {:timestamp      12348
    :entry-type     :pomodoro
    :planned-dur    1500
    :completed-time 1500}
   {:timestamp      12349
    :entry-type     :pomodoro
    :planned-dur    1500
    :completed-time 1500}
   {:timestamp      12350
    :entry-type     :pomodoro
    :planned-dur    1500
    :completed-time 1000}])

(deftest pomodoro-stats-test
  "Test that the pomodoro-stats properly summarizes pomodoro stats."
  (testing "works on empty seq of entries"
    (is (= (p/pomodoro-stats []) {:pomodoros           0
                                  :completed-pomodoros 0
                                  :total-time          0})))

  (testing "works on test entries"
    (is (= (p/pomodoro-stats (take 4 test-entries))
           {:pomodoros           3
            :completed-pomodoros 2
            :total-time          4000})))

  (testing "works on test entries with interruptions"
    (is (= (p/pomodoro-stats test-entries)
           {:pomodoros           5
            :completed-pomodoros 3
            :total-time          6500}))))

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
   :entry-type     :pomodoro
   :planned-dur    1500
   :comment-for    1465059139281
   :completed-time 0
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry2
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry-type     :pomodoro
   :planned-dur    1500
   :comment-for    1465059139281
   :completed-time 100
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry2a
  {:mentions         #{}
   :tags             #{"#cljc"}
   :timezone         "Europe/Berlin"
   :utc-offset       -120
   :entry-type       :pomodoro
   :pomodoro-running true
   :planned-dur      1500
   :comment-for      1465059139281
   :completed-time   100
   :timestamp        1465059173965
   :md               "Moving to #cljc"})

(def test-entry3
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry-type     :pomodoro
   :planned-dur    1500
   :comment-for    1465059139281
   :completed-time 1500
   :timestamp      1465059173965
   :md             "Moving to #cljc"})

(def test-entry3a
  {:mentions       #{}
   :tags           #{"#cljc"}
   :timezone       "Europe/Berlin"
   :utc-offset     -120
   :entry-type     :pomodoro
   :planned-dur    1500
   :comment-for    1465059139281
   :completed-time 1500
   :timestamp      1465059173965
   :md             "Moving to #cljc"})
