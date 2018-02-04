(ns meo.vclock-test
  (:require [clojure.test :refer :all]
            [meo.common.utils.vclock :as vc]))

(def some-node-id "some-node-id")
(def another-node-id "another-node-id")

(deftest new-global-vclock-test
  (testing "returns latest vclock values"
    (is (= {some-node-id    2
            another-node-id 1}
           (vc/new-global-vclock
             {some-node-id    1
              another-node-id 1}
             {:vclock {some-node-id 2}}))))

  (testing "returns original vclock when entry already known"
    (is (= {some-node-id    2
            another-node-id 1}
           (vc/new-global-vclock
             {some-node-id    2
              another-node-id 1}
             {some-node-id 2}))))

  (testing "ignores non-numbers"
    (is (= {some-node-id    2
            another-node-id 1}
           (vc/new-global-vclock
             {some-node-id    2
              another-node-id 1}
             {some-node-id :foo})))))

(deftest next-global-vclock-test
  (testing "next global vclock state is generated correctly"
    (is (= {another-node-id 1
            some-node-id    3}
           (vc/next-global-vclock
             {:cfg           {:node-id some-node-id}
              :global-vclock {some-node-id    2
                              another-node-id 1}}))))

  (testing "add node id when not known yet"
    (is (= {another-node-id       1
            some-node-id          2
            "yet-another-node-id" 1}
           (vc/next-global-vclock
             {:cfg           {:node-id "yet-another-node-id"}
              :global-vclock {some-node-id    2
                              another-node-id 1}})))))

(deftest set-latest-vclock-test
  (testing "vclock set correctly"
    (is (= {:vclock {some-node-id 2}}
           (vc/set-latest-vclock
             {:vclock {some-node-id 2}}
             some-node-id
             {some-node-id 2})))))

(deftest vlock-comparator-test
  (testing "return :equal when both clocks are the same"
    (is (= :equal
           (vc/vlock-comparator
             {some-node-id    1
              another-node-id 2}
             {some-node-id    1
              another-node-id 2}))))
  (testing "returns :conflict when there is a conflict"
    (is (= :conflict
           (vc/vlock-comparator
             {some-node-id    2
              another-node-id 1}
             {some-node-id    1
              another-node-id 2}))))
  (testing "returns :a>b when a is strictly greater than b"
    (is (= :a>b
           (vc/vlock-comparator
             {some-node-id    2
              another-node-id 1}
             {some-node-id    1
              another-node-id 1}))))
  (testing "returns :b>a when b is strictly greater than a"
    (is (= :a>b
           (vc/vlock-comparator
             {some-node-id    2
              another-node-id 1}
             {some-node-id    1
              another-node-id 1})))))
