(ns meins.store-add-test
  "Here, we test the handler functions of the server side store component."
  (:require [clojure.pprint :as pp]
            [clojure.test :refer [deftest is testing]]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.files :as f]
            [meins.jvm.graph.stats :as gs]
            [meins.store-test :as st]
            [meins.store-test-common :as stc]))

(def pvt-test-entries
  [{:mentions  #{}
    :tags      #{"#task" "#pvt"}
    :timestamp 1450999000000
    :md        "Some other #task #pvt"}
   {:mentions  #{}
    :tags      #{"#pvt" "#new-pvt-tag"}
    :timestamp 1450999100000
    :md        "Something #pvt #new-pvt-tag"}
   {:mentions  #{}
    :tags      #{"#task" "#done"}
    :timestamp 1450999200000
    :md        "Some other #task #done"}
   {:mentions  #{"@someone"}
    :tags      #{"#task" "#completed" "#done"}
    :timestamp 1450999300000
    :md        "Yet another completed #task - #done @someone"}
   {:mentions  #{"@JaneDoe"}
    :tags      #{"#task" "#completed" "#done"}
    :timestamp 1450999400000
    :md        "And yet another completed #task - #done @JaneDoe"}])

(deftest add-test
  "Test that entries are added correctly, including building the
   hashtags and mentions sets."
  (let [test-ts (System/currentTimeMillis)
        {:keys [current-state logs-path]} (st/mk-test-state test-ts)]
    (with-redefs [fu/daily-logs-path logs-path]
      (let [new-state (reduce stc/persist-reducer current-state stc/test-entries)
            new-state2 (reduce stc/persist-reducer new-state pvt-test-entries)]

        (testing
          "private hashtags are set correctly"
          (let [res (gs/make-stats-tags new-state)
                pvt-hashtags (:pvt-hashtags res)]
            (is (= {"#pvt"   2
                    "#thing" 2}
                   pvt-hashtags))))

        (testing
          "private hashtags are extended as expected:
             * added #new-pvt-tag
             * #task not added as private tag"
          (let [res (gs/make-stats-tags new-state2)
                pvt-hashtags (:pvt-hashtags res)]
            (is (= {"#new-pvt-tag" 2
                    "#pvt"         4
                    "#thing"       2}
                   pvt-hashtags))))

        (testing
          "hashtags and mentions in result of stats-tags publish fn"
          (let [res (gs/make-stats-tags new-state2)]
            (is (= #{["#comment" 2]
                     ["#completed" 5]
                     ["#done" 7]
                     ["#task" 10]}
                   (set (:hashtags res))))
            (is (= #{["#new-pvt-tag" 2]
                     ["#pvt" 4]
                     ["#thing" 2]}
                   (set (:pvt-hashtags res))))
            (is (= (:pvt-displayed res) stc/private-tags))
            (is (= #{"@JaneDoe" "@someone"} (:mentions res)))))))))
