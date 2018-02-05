(ns meo.common.utils.vclock
  (:require [clojure.set :as set]
            [clojure.spec.alpha :as s]
            [meo.common.specs]
            [expound.alpha :as exp]))

(defn next-global-vclock [current-state]
  (let [global-vclock (:global-vclock current-state)
        node-id (-> current-state :cfg :node-id)]
    (update-in global-vclock [node-id] #(inc (or % 0)))))

(defn new-global-vclock [global-vclock parsed]
  (reduce (fn [acc [node-id cnt]]
            (if (number? cnt)
              (update-in acc [node-id] #(max (or % 1) cnt))
              acc))
          global-vclock
          (:vclock parsed)))

(defn set-latest-vclock [entry node-id new-global-vclock]
  (let [latest-vclock-cnt (get-in new-global-vclock [node-id])]
    (assoc-in entry [:vclock node-id] latest-vclock-cnt)))

(s/def :meo.vclock/node-id string?)
(s/def :meo.vclock/counter int?)
(s/def :meo.vclock/map (s/map-of :meo.vclock/node-id :meo.vclock/counter))

(defn vclock-comparator [a b]
  "Compares two vector clock maps. Those maps consist of node id strings as keys
   and an integer as value, which is the offset on the node associated with
   persisting the particular entry. See examples in the tests.

   Will return :a>b if vclock a dominates b, :b>a in the opposite
   case, :equal if they are the same, and :concurrent if a strict order could
   not be determined.

   Throws an exception when input is invalid."
  (let [a-valid (s/valid? :meo.vclock/map a)
        b-valid (s/valid? :meo.vclock/map b)]
    (if (and a-valid b-valid)
      (let [node-ids (set/union (set (keys a)) (set (keys b)))
            compare (fn [k]
                      (let [av (or (get a k 0))
                            bv (or (get b k 0))]
                        (cond
                          (> av bv) :a>b
                          (> bv av) :b>a
                          :else :equal)))
            comparisons (set (map compare node-ids))]
        (cond
          (= a b) :equal
          (and (contains? comparisons :a>b)
               (not (contains? comparisons :b>a))) :a>b
          (and (contains? comparisons :b>a)
               (not (contains? comparisons :a>b))) :b>a
          :else :concurrent))
      (throw (Exception. (str (exp/expound-str :meo.vclock/map a)
                              (exp/expound-str :meo.vclock/map b)))))))
