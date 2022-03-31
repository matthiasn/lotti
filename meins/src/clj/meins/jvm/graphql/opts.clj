(ns meins.jvm.graphql.opts
  "GraphQL query component"
  (:require [clj-pid.core :as pid]
            [com.climate.claypoole :as cp]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.graph.stats :as gs]
            [meins.jvm.graphql.custom-fields :as gcf]
            [taoensso.timbre :refer [debug error info warn]]))

(defn entry-count
  [state _context _args _value]
  (count (:sorted-entries @state)))

(defn hours-logged
  [state _context _args _value]
  (gs/hours-logged @state))

(defn word-count
  [state _context _args _value]
  (gs/count-words @state))

(defn tag-count
  [state _context _args _value]
  (count (gq/find-all-hashtags @state)))

(defn mention-count
  [state _context _args _value]
  (count (gq/find-all-mentions @state)))

(defn completed-count
  [state _context _args _value]
  (gs/completed-count @state))

(defn hashtags
  "Regular tags without private tags"
  [state _context _args _value]
  (let [tags (-> @state :options :hashtags)
        pvt-tags (-> @state :options :pvt-hashtags)
        without-pvt (apply dissoc tags (keys pvt-tags))]
    (->> without-pvt
         (sort-by second)
         reverse
         (map first))))

(defn pvt-hashtags
  "All tags, including private."
  [state _context _args _value]
  (let [tags (-> @state :options :hashtags)
        pvt-tags (-> @state :options :pvt-hashtags)
        merged (merge tags pvt-tags)]
    (->> merged
         (sort-by second)
         reverse
         (map first))))

(defn mentions
  [state _context _args _value]
  (-> @state :options :mentions))

(defn stories
  [state _context _args _value]
  (gq/find-all-stories2 @state))

(defn sagas
  [state _context _args _value]
  (gq/find-all-sagas2 @state))

(defn thread-count
  [_state _context _args _value]
  (Thread/activeCount))

(defn pid
  [_state _context _args _value]
  (pid/current))

(defn briefings
  [state _context _args _value]
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
