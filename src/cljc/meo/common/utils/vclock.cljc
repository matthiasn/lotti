(ns meo.common.utils.vclock)

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

(defn vlock-comparator [a b]
  "Compares two vector clock maps. Those maps consist of node id strings as keys
   and an integer, which is the counter on the particular node associated with
   persisting the particular entry. See examples in the tests.
   Will return :a>b if vclock a is strictly greater than b, :b>a in the opposite
   case, :equal if they are the same, and :conflict if there is are conflict
   that requires user interaction."
  (let [cmps (set (map (fn [[k av]]
                         (let [bv (or (get b k 0))]
                           (cond
                             (> av bv) :a>b
                             (> bv av) :b>a
                             :else :equal)))
                       a))]
    (cond
      (= a b) :equal
      (and (contains? cmps :a>b)
           (not (contains? cmps :b>a))) :a>b
      (and (contains? cmps :b>a)
           (not (contains? cmps :a>b))) :b>a
      :else :conflict)))
