(ns meins.common.utils.vclock
  (:require [clojure.set :as set]
            [clojure.spec.alpha :as s]
            [expound.alpha :as exp]
            [meins.common.specs]))

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

(s/def :meins.vclock/node-id string?)
(s/def :meins.vclock/counter int?)
(s/def :meins.vclock/map (s/map-of :meins.vclock/node-id :meins.vclock/counter))

(defn vclock-compare
  "Compares two vector clocks. A and B are maps with node id strings as keys
   and an integer as value, which is the offset on the node associated with
   persisting the particular entry. See examples in the tests.

   Will return :a>b if clock B dominates A, :b>a in the opposite
   case, :equal if they are the same, and :concurrent if no strict order could
   be determined.

   Throws an exception when input is invalid."
  [a b]
  (let [a-valid (s/valid? :meins.vclock/map a)
        b-valid (s/valid? :meins.vclock/map b)]
    (if (and a-valid b-valid)
      (let [node-ids (set/union (set (keys a)) (set (keys b)))
            compare (fn [k]
                      (let [av (get a k 0)
                            bv (get b k 0)]
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
      (let [err (str (exp/expound-str :meins.vclock/map a)
                     (exp/expound-str :meins.vclock/map b))]
        #?(:clj (throw (Exception. err))
           :cljs (throw (js/Error err)))))))
