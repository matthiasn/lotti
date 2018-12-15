(ns meo.jvm.graphql.opts
  "GraphQL query component"
  (:require [taoensso.timbre :refer [info error warn debug]]
            [matthiasn.systems-toolbox.component :as stc]
            [com.climate.claypoole :as cp]
            [meo.jvm.graph.stats :as gs]
            [meo.jvm.graph.query :as gq]
            [meo.jvm.graphql.custom-fields :as gcf]
            [clj-pid.core :as pid]))

(defn entry-count [state context args value] (count (:sorted-entries @state)))
(defn hours-logged [state context args value] (gs/hours-logged @state))
(defn word-count [state context args value] (gs/count-words @state))
(defn tag-count [state context args value] (count (gq/find-all-hashtags @state)))
(defn mention-count [state context args value] (count (gq/find-all-mentions @state)))
(defn completed-count [state context args value] (gs/completed-count @state))

(defn hashtags [state context args value]
  "Regular tags without private tags"
  (let [tags (-> @state :options :hashtags)
        pvt-tags (-> @state :options :pvt-hashtags)
        without-pvt (apply dissoc tags (keys pvt-tags))]
    (->> without-pvt
         (sort-by second)
         reverse
         (map first))))

(defn pvt-hashtags [state context args value]
  "All tags, including private."
  (let [tags (-> @state :options :hashtags)
        pvt-tags (-> @state :options :pvt-hashtags)
        merged (merge tags pvt-tags)]
    (->> merged
         (sort-by second)
         reverse
         (map first))))

(defn mentions [state context args value] (-> @state :options :mentions))
(defn stories [state context args value] (gq/find-all-stories2 @state))
(defn sagas [state context args value] (gq/find-all-sagas2 @state))

(defn thread-count [state context args value] (Thread/activeCount))
(defn pid [state context args value] (pid/current))

(defn briefings [state context args value]
  (map (fn [[k v]] {:day k :timestamp v})
       (gq/find-all-briefings @state)))

(def thread-pool (cp/priority-threadpool 3))

(defn gen-opt [cmp-state f k]
  (cp/future
    thread-pool
    (let [start (stc/now)]
      (swap! cmp-state assoc-in [:options k] (f @cmp-state))
      (info "options" k (- (stc/now) start) "ms"))))

(defn gen-options [{:keys [cmp-state]}]
  (gen-opt cmp-state gq/find-all-hashtags :hashtags)
  (gen-opt cmp-state gq/find-all-mentions :mentions)
  (gen-opt cmp-state gq/find-all-pvt-hashtags :pvt-hashtags)
  (gen-opt cmp-state gcf/custom-fields-cfg :custom_fields)
  {})
