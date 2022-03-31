(ns meins.client-store-entry-test
  "Here, we test the handler functions of the server side store component."
  (:require #?(:clj  [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
            [meins.electron.renderer.client-store :as cs]
            [meins.electron.renderer.client-store.entry :as cse]))

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

(def entry-update
  {:timestamp 1465059173965
   :md        "Moving to #cljc. Edited entry."})

(def entry-geo-update
  {:mentions   #{}
   :tags       #{}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :longitude  9.9
   :latitude   53.5
   :timestamp  1465059173965
   :md         ""})

(deftest new-entry-test
  "Test that local entry is properly set in state."
  (with-redefs [cse/new-entries-ls (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (cse/new-entry-fn {:current-state current-state
                                                   :msg-payload   test-entry}))]
      (testing
        "pomodoro test entry in new-entries"
        (is (= test-entry (get-in new-state [:new-entries 1465059173965]))))
      (testing
        "new entries atom properly updated - this would be backed by
         localstorage on client"
        (is (= (:new-entries new-state) @cse/new-entries-ls))))))

(deftest update-local-test
  "Test that local entry is properly attached to state."
  (with-redefs [cse/new-entries-ls (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (cse/update-local
                                  {:current-state current-state
                                   :msg-payload   test-entry}))
          new-state2 (:new-state (cse/update-local
                                   {:current-state new-state
                                    :msg-payload   entry-update}))]
      (testing
        "pomodoro test entry in new-entries"
        (is (= test-entry (get-in new-state [:new-entries 1465059173965]))))
      (testing
        "entry update is merged with previous entry, thus allows omitting keys"
        (is (= (merge test-entry entry-update)
               (get-in new-state2 [:new-entries 1465059173965]))))
      (testing
        "new entries atom properly updated - this would be backed by
         localstorage on client"
        (is (= (:new-entries new-state2) @cse/new-entries-ls))))))

(deftest remove-local-test
  "Test that local entry is properly removed from state after delete message."
  (with-redefs [cse/new-entries-ls (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (cse/update-local
                                  {:current-state current-state
                                   :msg-payload   test-entry}))
          new-state2 (:new-state (cse/remove-local
                                   {:current-state new-state
                                    :msg-payload   entry-update}))]
      (testing
        "pomodoro test entry in new-entries"
        (is (= test-entry (get-in new-state [:new-entries 1465059173965]))))
      (testing
        "entry update is removed from component state"
        (is (not (get-in new-state2 [:new-entries 1465059173965]))))
      (testing
        "new entries atom properly updated - this would be backed by
         localstorage on client"
        (is (= (:new-entries new-state2) @cse/new-entries-ls))))))

(deftest entry-saved-test
  "New entry removed after backend confirms save."
  (with-redefs [cse/new-entries-ls (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (cse/update-local
                                  {:current-state current-state
                                   :msg-payload   test-entry}))
          new-state (:new-state (cse/update-local
                                  {:current-state new-state
                                   :msg-payload   entry-update}))
          new-state2 (:new-state (cse/entry-saved-fn
                                   {:current-state new-state
                                    :msg-payload   entry-update
                                    :put-fn        (fn [_])}))]
      (testing
        "test entry in new-entries"
        (is (= (merge test-entry entry-update)
               (get-in new-state [:new-entries 1465059173965]))))
      (testing
        "entry update is removed from component state after receiving save
         confirmation"
        (is (not (get-in new-state2 [:new-entries 1465059173965]))))
      (testing
        "new entries atom properly updated - this would be backed by
         localstorage on client"
        (is (= (:new-entries new-state2) @cse/new-entries-ls))))))

(def pomodoro-inc-msg
  {:timestamp 1465059173965})
#_(deftest pomodoro-inc-test
    "Test the time increment handler for running pomodoros. Expectation is that
     the :completed-time key is incremented on every call."
    (let [play-counter (atom {"ticking-clock" 0 "ringer" 0})]
      (with-redefs [cse/new-entries-ls (atom {})
                    cse/play-audio (fn [id] (swap! play-counter update-in [id] inc))]
        (let [current-state @(:state (store/initial-state-fn (fn [_put-fn])))
              current-state (assoc-in current-state [:cfg :mute] false)
              current-state (assoc-in current-state [:cfg :ticking-clock] true)
              new-state (:new-state (cse/update-local
                                      {:current-state current-state
                                       :msg-payload   test-entry}))
              new-state1 (:new-state (cse/pomodoro-start
                                       {:current-state new-state
                                        :msg-payload   test-entry}))
              new-state2 (:new-state (cse/pomodoro-inc
                                       {:current-state new-state1
                                        :msg-payload   pomodoro-inc-msg}))
              new-state3 (:new-state (cse/pomodoro-inc
                                       {:current-state new-state2
                                        :msg-payload   pomodoro-inc-msg}))]
          (testing
            "pomodoro test entry in new-entries"
            (is (= test-entry (get-in new-state [:new-entries 1465059173965]))))
          (testing
            "pomodoro set to running"
            (is (:pomodoro-running (get-in new-state1 [:new-entries 1465059173965]))))
          (testing
            "time incremented"
            (is (= 1 (get-in new-state2
                             [:new-entries 1465059173965 :completed-time]))))
          (testing
            "time incremented"
            (is (= 2 (get-in new-state3
                             [:new-entries 1465059173965 :completed-time]))))
          (testing
            "new entries atom properly updated - this would be backed by
             localstorage on client"
            (is (= (:new-entries new-state3) @cse/new-entries-ls)))
          (testing
            "tick was played twice"
            (is (= 2
                   (get-in @play-counter ["ticking-clock"]))))))))
#_(deftest pomodoro-start-test
    "Tests that the pomodoro-start handler properly sets the entry status to
     started and and stopped."
    (with-redefs [cse/new-entries-ls (atom {})
                  cse/play-audio (fn [_id])]
      (let [current-state @(:state (store/initial-state-fn (fn [_put-fn])))
            new-state (:new-state (cse/update-local
                                    {:current-state current-state
                                     :msg-payload   test-entry}))
            new-state1 (:new-state (cse/pomodoro-start
                                     {:current-state new-state
                                      :msg-payload   test-entry}))
            new-state2 (:new-state (cse/pomodoro-inc
                                     {:current-state new-state1
                                      :msg-payload   pomodoro-inc-msg}))
            new-state3 (:new-state (cse/pomodoro-start
                                     {:current-state new-state2
                                      :msg-payload   test-entry}))]
        (testing
          "pomodoro test entry in new-entries"
          (is (= test-entry (get-in new-state [:new-entries 1465059173965]))))
        (testing
          "pomodoro set to running"
          (is (:pomodoro-running
                (get-in new-state1 [:new-entries 1465059173965]))))
        (testing
          "time incremented"
          (is (= 1 (get-in new-state2
                           [:new-entries 1465059173965 :completed-time]))))
        (testing
          "pomodoro set to not running"
          (is (not (:pomodoro-running
                     (get-in new-state3 [:new-entries 1465059173965])))))
        (testing
          "new entries atom properly updated - this would be backed by
           localstorage on client"
          (is (= (:new-entries new-state3) @cse/new-entries-ls))))))
