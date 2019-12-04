(ns meins.client-store-test
  "Here, we test the handler functions of the server side store component."
  (:require #?(:clj [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
                    [meins.electron.renderer.client-store :as cs]
                    [meins.electron.renderer.client-store.cfg :as c]))

(def empty-query
  {:search-text ""
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :date_string nil
   :timestamp   nil
   :n           40
   :query-id    :query-1
   :sort-asc    nil})

(def open-tasks-query
  {:search-text "#task ~#done "
   :tags        #{"#task"}
   :not-tags    #{"~#done"}
   :mentions    #{}
   :date_string nil
   :timestamp   nil
   :n           40
   :query-id    :query-1
   :sort-asc    nil})

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

(def state-from-backend
  {:entries             [(:timestamp test-entry)]
   :entries-map         {(:timestamp test-entry) test-entry}
   :linked-entries-list []
   :duration-ms         19
   :query-id            :query-1})

(def stats-tags-from-backend
  {:hashtags #{"#drama" "#hashtag" "#blah"}
   :mentions #{"@myself" "@me" "@I"}
   :stats    {:entry-count 4118 :node-count 5636 :edge-count 28726}})

(def meta-from-backend
  {:server/ws-cmp       {:out-ts 1467748026835
                         :in-ts  1467748026845}
   :sente-uid           "b1ea383d-f1b1-42fe-9125-f5953e605cd7"
   :cmp-seq             [:client/search-cmp :client/store-cmp :client/ws-cmp
                         :server/store-cmp :server/store-cmp :server/ws-cmp
                         :client/store-cmp]
   :server/store-cmp    {:in-ts  1467748026835
                         :out-ts 1467748026845}
   :renderer/store-cmp  {:out-ts 1467748026813
                         :in-ts  1467748026870}
   :renderer/search-cmp {:out-ts 1467748026684}
   :renderer/ws-cmp     {:in-ts  1467748026814
                         :out-ts 1467748026869}
   :tag                 "5a5183de-ee04-4b2f-9dbf-aa4fe2c245f7"
   :corr-id             "39476852-fdc1-474a-a933-76cc83a55b31"})

(def entry-update
  {:timestamp 1465059173965
   :md        "Moving to #cljc. Edited entry."})

(def entry-geo-update
  {:mentions   #{}
   :tags       #{}
   :timezone   "Europe/Berlin"
   :new-entry  true
   :utc-offset -120
   :longitude  9.9
   :latitude   53.5
   :timestamp  1465059173965
   :md         ""})

#_(deftest new-state-test
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (csi/new-state-fn
                                  {:current-state current-state
                                   :msg-payload   state-from-backend
                                   :msg-meta      meta-from-backend}))]
      (testing
        "entries are on new state"
        (is (= (get-in new-state [:results])
               (:entries state-from-backend))))
      (testing
        "entries map is on new state"
        (is (= (:entries-map new-state) (:entries-map state-from-backend))))
      (testing
        "query duration is on new state"
        (is (= (:query (:timing new-state)) (:duration-ms state-from-backend)))
        (is (= (:rtt (:timing new-state)) 57)))))

(deftest toggle-key-test
  "toggle key messages flip boolean value"
  (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
        new-state (:new-state (c/toggle-key-fn
                                {:current-state current-state
                                 :msg-payload   {:path [:cfg :sort-by-upvotes]}}))
        new-state2 (:new-state (c/toggle-key-fn
                                 {:current-state current-state
                                  :msg-payload   {:path [:some :crazy :long :path]}}))]
    (testing
      "before receiving toggle-key msg, key is false, as per initial state"
      (is (not (:sort-by-upvotes (:cfg current-state)))))
    (testing
      "after receiving toggle-key msg, key is true"
      (is (:sort-by-upvotes (:cfg new-state))))
    (testing
      "previously unknown key is set to true. can be nested"
      (is (get-in new-state2 [:some :crazy :long :path])))))

(deftest toggle-set-test
  "toggle key messages flip boolean value"
  (let [test-ts 1465059139281
        path [:cfg :show-maps-for]
        current-state @(:state (cs/state-fn (fn [_put-fn])))
        new-state (:new-state (c/toggle-set-fn
                                {:current-state current-state
                                 :msg-payload   {:timestamp test-ts :path path}}))
        new-state1 (:new-state (c/toggle-set-fn
                                 {:current-state new-state
                                  :msg-payload   {:timestamp test-ts :path path}}))]
    (testing
      "cfg set is initially empty"
      (is (empty? (:show-maps-for (:cfg current-state)))))
    (testing
      "set contains timestamp after initial toggle"
      (is (contains? (:show-maps-for (:cfg new-state)) test-ts)))
    (testing
      "timestamp removed from set after subsequent toggle"
      (is (not (contains? (:show-maps-for (:cfg new-state1)) 1465059139281))))))
