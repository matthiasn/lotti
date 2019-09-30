(ns meins.res-diff-test
  (:require [clojure.set :as set]
            [clojure.test :refer [deftest is testing]]
            [meins.jvm.graphql.tab-search :as gts]))

(def prev-res-1
  [{:timestamp 123455
    :md        "123455a"}
   {:timestamp 123456
    :md        "123456a"}
   {:timestamp 123457
    :md        "1234567a"}])

(def new-res-1
  [{:timestamp 123456
    :md        "123456a"}
   {:timestamp 123457
    :md        "1234567b"}])


(deftest new-or-updated-only-test
  (testing "works with empty results"
    (is (= {:del #{}
            :res #{}}
           (gts/res-diff [] []))))
  (testing "returns only entries in new result"
    (is (= {:del #{123455
                   123457}
            :res #{{:md        "1234567b"
                    :timestamp 123457}}}
           (gts/res-diff prev-res-1 new-res-1)))))
