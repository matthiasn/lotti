(ns meins.vclock-test
  (:require [clojure.test :refer :all]
            [clojure.test.check :as tc]
            [clojure.test.check.generators :as gen]
            [clojure.test.check.properties :as prop]
            [meins.common.utils.vclock :as vc]))

(def some-node-id "some-node-id")
(def another-node-id "another-node-id")
(def yet-another-node-id "yet-another-node-id")

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

(deftest vclock-comparator-test

  (testing "return :equal when both clocks are the same"
    (is (= :equal
           (vc/vclock-compare
             {some-node-id    1
              another-node-id 2}
             {some-node-id    1
              another-node-id 2}))))

  (testing "returns :conflict when there is a conflict"
    (is (= :concurrent
           (vc/vclock-compare
             {some-node-id    2
              another-node-id 1}
             {some-node-id    1
              another-node-id 2}))))

  (testing "returns :a>b when A dominates B"
    (is (= :a>b
           (vc/vclock-compare
             {some-node-id    2
              another-node-id 1}
             {some-node-id    1
              another-node-id 1}))))

  (testing "returns :b>a when B dominates A via additional node"
    (is (= :b>a
           (vc/vclock-compare
             {some-node-id    2
              another-node-id 1}
             {some-node-id        2
              another-node-id     1
              yet-another-node-id 3}))))

  (testing "returns :concurrent both A updated and B has a previously unknown node"
    (is (= :concurrent
           (vc/vclock-compare
             {some-node-id    3
              another-node-id 1}
             {some-node-id        2
              another-node-id     1
              yet-another-node-id 3}))))

  (testing "throws exception if A is invalid"
    (is (thrown? Exception
                 (vc/vclock-compare
                   {:foo 1
                    3    "a"}
                   {some-node-id        2
                    another-node-id     1
                    yet-another-node-id 3}))))

  (testing "throws exception if B is invalid"
    (is (thrown? Exception
                 (vc/vclock-compare
                   {some-node-id        2
                    another-node-id     1
                    yet-another-node-id 3}
                   {:foo 1
                    3    "a"})))))


;;; QuickCheck tests for comparing vector clocks.
;;; First, a generator for valid node-ids, which are non-empty strings.
(def gen-not-empty-alphanumeric
  (gen/such-that not-empty gen/string-alphanumeric))

;;; Generator for valid vclocks that creates maps with node-ids as key and
;;; positive integers as values.
(def gen-vclock
  (gen/such-that
    not-empty
    (gen/map gen-not-empty-alphanumeric gen/pos-int)))

;;; Another generator gives us expected comparison results.
(def gen-type (gen/elements [:a>b :b>a :concurrent :equal]))

;;; Generator for tuples of vclocks and one of the gen-types.
(def gen-vclock-type-pair (gen/tuple gen-vclock gen-type))

(defn change-vclock
  "Changes value at index determined by pos-fn (e.g. first, last) by applying
   op to the value at the key found by pos-fn."
  [op pos-fn]
  (fn [vclock]
    (if (empty? vclock)
      {}
      (let [first-node (pos-fn (keys vclock))]
        (update-in vclock [first-node] op)))))

;;; Functions for modifying vclock for use in create-expectation below.
(def make-lower (change-vclock dec first))
(def make-greater (change-vclock inc first))

(defn create-conflict
  "Takes vclock map and modifies one entry plus inserts 1 at another key."
  [vclock]
  (let [first-node (first (keys vclock))
        updated (update-in vclock [first-node] dec)]
    (assoc-in updated ["______concurrent"] 1)))

(defn create-expectation
  "Takes a tuple of vclock and mutation to perform, then performs that mutation."
  [[vclock mutation]]
  (cond
    (= mutation :equal) [vclock vclock :equal]
    (= mutation :a>b) [vclock (make-lower vclock) :a>b]
    (= mutation :b>a) [vclock (make-greater vclock) :b>a]
    (= mutation :concurrent) [(make-greater vclock)
                              (create-conflict vclock)
                              :concurrent]))

;;; Generator that generates vclock/expectation pairs, where the vclocks
;;; are modified so that they should meet the expectation.
(def gen-l-r-expected (gen/fmap create-expectation gen-vclock-type-pair))

;;; Property for asserting that vc/vclock-comparator gives the expected result
;;; for all tuples generated by gen-l-r-expected.
(def property
  (prop/for-all [v gen-l-r-expected]
                (let [[a b exp] v]
                  (= (vc/vclock-compare a b) exp))))

(deftest vclock-quick-check
  (testing "property checks for successful vector clock comparison"
    (is (:result (tc/quick-check 500 property)))))

;;; Property for asserting symmetry, such that when passing the same values
;;; into vc/vclock-comparator in opposite order, we get the opposite results
;;; in the cases of :a>b and :b>a, and :equal and :concurrent regardless of
;;; order.
(def symmetry-property
  (prop/for-all [v gen-l-r-expected]
                (let [[a b exp] v]
                  (cond
                    (= exp :equal)
                    (= (vc/vclock-compare a b) (vc/vclock-compare b a))

                    (= exp :concurrent)
                    (= (vc/vclock-compare a b) (vc/vclock-compare b a))

                    (= exp :a>b)
                    (and (= (vc/vclock-compare a b) :a>b)
                         (= (vc/vclock-compare b a) :b>a))

                    (= exp :b>a)
                    (and (= (vc/vclock-compare a b) :b>a)
                         (= (vc/vclock-compare b a) :a>b))))))

(deftest vclock-symmetry-test
  (testing "property checks for vector clock comparison succeed"
    (is (:result (tc/quick-check 500 symmetry-property)))))
