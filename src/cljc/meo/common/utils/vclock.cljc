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
