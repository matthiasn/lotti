(ns meins.jvm.graph.query
  "this namespace manages interactions with the graph data structure, which
  holds all entries and their connections."
  (:require [clj-time.coerce :as ctc]
            [clj-time.core :as ct]
            [clj-time.format :as ctf]
            [clj-uuid :as uuid]
            [clojure.pprint :as pp]
            [clojure.set :as set]
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.misc :as um]
            [meins.jvm.fulltext-search :as ft]
            [meins.jvm.graphql.xforms :as xf]
            [meins.jvm.metrics :as mt]
            [metrics.timers :as tmr]
            [taoensso.timbre :refer [debug error info warn]]
            [ubergraph.core :as uc]))

(defn get-node [state ts]
  (let [g (:graph state)]
    (when (and ts (uc/has-node? g ts))
      (xf/vclock-xf (uc/attrs g ts)))))

(defn get-entry [state ts]
  (get-in state [:entries-map ts]))

(defn get-entry-xf [state ts]
  (when-let [entry (get-entry state ts)]
    (xf/edn-xf entry)))

(defn entry-w-story [state entry]
  (let [story (get-entry state (:primary_story entry))
        saga (get-entry state (:linked_saga story))]
    (merge entry
           {:story (when story
                     (assoc-in story [:saga] saga))})))

;; TODO: migrate existing audio entries to use a different keyword
(defn summed-durations
  "Calculate time spent as tracked in custom fields."
  [entry]
  (let [custom-fields (:custom_fields entry)]
    (if (map? custom-fields)
      (apply + (filter identity (mapv (fn [[k v]]
                                        (let [dur (:duration v)]
                                          (if (= k "#audio")
                                            0
                                            (* 60 (or dur 0)))))
                                      custom-fields)))
      0)))

(def dtz (ct/default-time-zone))
(def fmt (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))
(defn parse [dt] (ctf/parse fmt dt))

(defn entries-filter-fn
  "Creates a filter function which ensures that all tags and mentions in the
   query are contained in the filtered entry or any of it's comments, and none
   of the not-tags. Also allows filtering per day."
  [q state]
  (fn [entry]
    (let [local-fmt (ctf/with-zone (ctf/formatters :year-month-day)
                                   (ct/default-time-zone))
          entry-day (ctf/unparse local-fmt (ctc/from-long (:timestamp entry)))
          adjusted-day (when-let [adjusted-ts (:adjusted_ts entry)]
                         (ctf/unparse local-fmt (ctc/from-long adjusted-ts)))
          q-day (:date_string q)
          day-match? (or (= q-day entry-day)
                         (= q-day adjusted-day)
                         (when-let [completion-day (:completion_ts (:task entry))]
                           (= q-day (subs completion-day 0 10))))

          q-timestamp (:timestamp q)
          q-ts-match? (= q-timestamp (str (:timestamp entry)))

          q-country (:country q)
          q-cc-match? (= q-country (-> entry :geoname :country-code))

          q-tags (set (mapv um/lower-case (:tags q)))
          q-not-tags (set (mapv um/lower-case (:not-tags q)))
          q-mentions (set (mapv um/lower-case (:mentions q)))

          tags (set/union (set (mapv um/lower-case (:tags entry)))
                          (set (mapv um/lower-case (:perm_tags entry))))

          entry-comments (mapv #(get-entry state %) (:comments entry))
          entry-comments-tags (apply set/union (mapv :tags entry-comments))
          tags (set (mapv um/lower-case (set/union tags entry-comments-tags)))

          mentions (set (mapv um/lower-case (:mentions entry)))
          entry-comments-mentions (apply set/union (mapv :mentions entry-comments))
          mentions (set (mapv um/lower-case (set/union mentions entry-comments-mentions)))

          story-match? (if-let [story (:story q)]
                         (or (= story (:primary_story entry))
                             (= story (:timestamp entry)))
                         true)
          starred-match? (if (:starred q) (:starred entry) true)
          flagged-match? (if (:flagged q) (:flagged entry) true)
          opts (:opts q)
          opts-match?
          (cond
            (contains? opts ":started")
            (when (contains? tags "#task")
              (let [nodes (into [entry] entry-comments)
                    filter-fn (fn [n]
                                (let [completed (:completed_time n)]
                                  (or (when completed (pos? completed))
                                      (pos? (summed-durations n)))))
                    started (filter filter-fn nodes)]
                (seq started)))

            (contains? opts ":waiting")
            (when (contains? tags "#habit")
              (when-let [active-from (get-in entry [:habit :active_from])]
                (let [from (parse active-from)
                      now (ct/now)
                      today-at (ct/from-time-zone
                                 (ct/today-at (ct/hour from) (ct/minute from))
                                 dtz)
                      habit (:habit entry)]
                  (and (not (:done habit))
                       (not (:skipped habit))
                       (ct/after? now from)
                       (ct/after? now today-at)))))

            (contains? opts ":due")
            (let [due-ts (:due (:task entry))]
              (when due-ts
                (> (st/now) due-ts)))

            (contains? opts ":done")
            (or (-> entry :task :done)
                (-> entry :habit :done))

            (contains? opts ":no-start")
            (not (:start (:task entry)))

            (contains? opts ":no-due")
            (not (:due (:task entry)))

            (contains? opts ":story")
            (= :story (:entry_type entry))

            (contains? opts ":no-story")
            (not (:primary_story entry))

            (contains? opts ":predicted-stories")
            (and (not (:primary_story entry))
                 (not (:briefing entry))
                 (not (contains? (:tags entry) "#briefing"))
                 (not (= :saga (:entry_type entry))))

            (contains? opts ":saga")
            (= :saga (:entry_type entry))

            :else true)

          match? (and (set/subset? q-tags tags)
                      (empty? (set/intersection q-not-tags tags))
                      (or (empty? q-mentions)
                          (seq (set/intersection q-mentions mentions)))
                      (or day-match? (empty? q-day))
                      (or q-cc-match? (empty? q-country))
                      (or q-ts-match? (empty? q-timestamp))
                      story-match?
                      starred-match?
                      flagged-match?
                      opts-match?)]
      match?)))

(defn get-comments
  "Extract all comments for entry."
  [entry g ts]
  (let [edges (uc/find-edges g {:dest ts :relationship :COMMENT})
        comment-ids (->> (flatten edges)
                         (remove :mirror?)
                         (map :src)
                         (sort))]
    (merge entry {:comments (vec comment-ids)})))

(defn get-tags-mentions-matches
  "Extract matching timestamps for query."
  [g query]
  (let [mapper (fn [tag-type]
                 (fn [tag]
                   (let [q {:src {tag-type tag} :relationship :CONTAINS}
                         edges (uc/find-edges g q)]
                     (set (mapv :dest edges)))))
        t-matched (mapv (mapper :tag) (mapv um/lower-case (:tags query)))
        nt-matched (mapv (mapper :tag) (mapv um/lower-case (:not-tags query)))
        ntp-matched (mapv (mapper :ptag) (mapv um/lower-case (:not-tags query)))
        pt-matched (mapv (mapper :ptag) (mapv um/lower-case (:tags query)))
        m-matched (mapv (mapper :mention) (mapv um/lower-case (:mentions query)))
        match-sets (filter seq (concat t-matched pt-matched m-matched))
        matched (if (seq match-sets) (apply set/intersection match-sets) #{})
        not-matched (apply set/union (filter seq (concat nt-matched ntp-matched)))]
    (set/difference matched not-matched)))

(defn get-nodes-for-day [g query]
  (let [dt (ctf/parse (ctf/formatters :year-month-day) (:date_string query))]
    (set (mapv :dest (uc/find-edges g {:src          {:type  :timeline/day
                                                      :year  (ct/year dt)
                                                      :month (ct/month dt)
                                                      :day   (ct/day dt)}
                                       :relationship :DATE})))))

(defn get-done [g k]
  (set (mapv :dest (uc/find-edges g {:src k}))))

(defn get-linked-for-ts [g ts]
  (let [linked (->> (flatten (uc/find-edges g {:src ts :relationship :LINKED}))
                    (mapv :dest)
                    (sort))]
    (set linked)))

(defn get-linked-nodes [g query]
  (get-linked-for-ts g (Long/parseLong (:linked query))))

(defn get-briefing-for-day [g query]
  (when-let [briefing-day (:briefing query)]
    (let [dt (ctf/parse (ctf/formatters :year-month-day) briefing-day)
          day-node {:type  :timeline/day
                    :year  (ct/year dt)
                    :month (ct/month dt)
                    :day   (ct/day dt)}]
      (set (mapv :dest (uc/find-edges g {:src          day-node
                                         :relationship :BRIEFING}))))))

(defn get-connected-nodes [g node]
  (set (map :dest (uc/find-edges g {:src node}))))

(defn get-linked-entries
  "Extract all linked entries for entry, including their comments."
  [entry g n]
  (let [linked (->> (flatten (uc/find-edges g {:src n :relationship :LINKED}))
                    (map :dest)
                    (sort))]
    (merge entry {:linked_entries_list (vec linked)})))

(defn extract-sorted-entries
  "Extracts nodes and their properties in descending timestamp order by looking
   for node by mapping over the sorted set and extracting attributes for each
   node.
   Warns when node not in graph. (debugging, should never happen)"
  [state query]
  (let [started-timer (mt/start-timer ["graph" "query" "extract-sorted-entries"])
        g (:graph state)
        mapper-fn (fn [ts]
                    (if-let [entry (get-entry state ts)]
                      (-> entry
                          (get-comments g ts)
                          (get-linked-entries g ts))
                      (debug "extract-sorted-entries can't find node: " ts)))
        sort-fn #(into (sorted-set-by (if (:sort-asc query) < >)) %)
        opts (:opts query)
        matched-ids (cond
                      ; full-text search
                      (:ft-search query)
                      (ft/search query)

                      ; set with linked timestamps
                      (:linked query)
                      (get-linked-nodes g query)

                      ; set with the one timestamp in query
                      (:timestamp query)
                      #{(Long/parseLong (:timestamp query))}

                      ; set with the one id in query
                      (:id query)
                      #{(uuid/as-uuid (:id query))}

                      ; set with timestamps matching the day
                      (:date_string query)
                      (get-nodes-for-day g query)

                      ; set with starred entries
                      (:starred query)
                      (get-connected-nodes g :starred)

                      ; set with flagged entries
                      (:flagged query)
                      (get-connected-nodes g :flagged)

                      ; set with timestamps matching the day
                      (:briefing query)
                      (get-briefing-for-day g query)

                      ; query is for specific story
                      (:story query)
                      (get-in state [:sorted-story-entries (:story query)])

                      ; query is for tasks
                      (and (seq opts)
                           (contains? opts ":done"))
                      (get-connected-nodes g :done)

                      (and (seq (:opts query))
                           (contains? opts ":story"))
                      (get-connected-nodes g :stories)

                      (and (seq (:opts query))
                           (contains? opts ":predicted-stories"))
                      (let [order (if (contains? opts ":asc") identity reverse)]
                        (->> (:story-predictions state)
                             (sort-by #(:p-1 (second %)))
                             (order)
                             (map first)))

                      (and (seq opts)
                           (contains? opts ":saga"))
                      (get-connected-nodes g :sagas)

                      ; set with timestamps matching tags and mentions
                      (or (seq (:tags query)) (seq (:mentions query)))
                      (get-tags-mentions-matches g query)

                      ; set with all timestamps
                      :else (:sorted-entries state))
        matched-ids (if (or (sorted? matched-ids)
                            (contains? opts ":predicted-stories"))
                      matched-ids
                      (sort-fn matched-ids))
        matched-entries (map mapper-fn matched-ids)
        matched-entries (filter #(or (:briefing query)
                                     (not (:briefing %))) matched-entries)
        res (if (sorted? matched-ids)
              matched-entries
              (let [parent-ids (filter identity (map :comment_for matched-entries))
                    parents (map mapper-fn parent-ids)]
                (flatten [matched-entries parents])))]
    (tmr/stop started-timer)
    res))

(defn extract-sorted2
  "Extracts nodes and their properties in descending timestamp order by looking
   for node by mapping over the sorted set and extracting attributes for each
   node.
   Warns when node not in graph. (debugging, should never happen)"
  [state query]
  (let [started-timer (mt/start-timer ["graph" "query" "extract-sorted2"])
        g (:graph state)
        matched-ids (cond
                      ; full-text search
                      (:ft-search query)
                      (ft/search query)

                      ; set with the one timestamp in query
                      (:timestamp query)
                      #{(Long/parseLong (:timestamp query))}

                      ; set with the one id in query
                      (:id query)
                      #{(uuid/as-uuid (:id query))}

                      ; set with timestamps matching the day
                      (:date_string query)
                      (get-nodes-for-day g query)

                      ; set with timestamps matching the day
                      (:briefing query)
                      (get-briefing-for-day g query)

                      ; query is for specific story
                      (:story query)
                      (get-in state [:sorted-story-entries (:story query)])

                      ; query is for tasks
                      (and (seq (:opts query))
                           (contains? (:opts query) ":done"))
                      (get-connected-nodes g :done)

                      (and (seq (:opts query))
                           (contains? (:opts query) ":story"))
                      (get-connected-nodes g :stories)

                      (and (seq (:opts query))
                           (contains? (:opts query) ":saga"))
                      (get-connected-nodes g :sagas)

                      ; set with timestamps matching tags and mentions
                      (or (seq (:tags query)) (seq (:mentions query)))
                      (get-tags-mentions-matches g query)

                      ; set with all timestamps
                      :else (:sorted-entries state))]
    (tmr/stop started-timer)
    matched-ids))

(defn find-all-hashtags
  "Finds all hashtags used in entries by finding the edges that originate from
   the :hashtags node. Merges the tags in the :pvt-displayed key of the config
   files, as those are the private keys that should be available in the
   autosuggestions."
  [current-state]
  (let [g (:graph current-state)
        ltags (mapv #(-> % :dest :tag) (uc/find-edges g {:src :hashtags}))
        f (fn [lt]
            (let [tag (:val (get-node current-state {:tag lt}))
                  cnt (count (uc/find-edges g {:src {:tag lt}}))]
              [tag cnt]))
        tag-cnt (mapv f ltags)
        res (into {} tag-cnt)]
    res))

(defn find-all-pvt-hashtags
  "Finds all private hashtags. Private hashtags are either those used
   exclusively in entries marked private, or the tags in the config key
   :pvt-tags."
  [current-state]
  (let [g (:graph current-state)
        ltags (mapv #(-> % :dest :ptag) (uc/find-edges g {:src :pvt-hashtags}))
        f (fn [lt]
            (let [tag (:val (get-node current-state {:ptag lt}))
                  cnt (count (uc/find-edges g {:src {:ptag lt}}))]
              [tag cnt]))
        tag-cnt (mapv f ltags)
        res (into {} tag-cnt)]
    res))

(defn find-all-mentions
  "Finds all hashtags used in entries by finding the edges that originate from
   the :hashtags node."
  [current-state]
  (let [g (:graph current-state)
        lmentions (mapv #(-> % :dest :mention)
                        (uc/find-edges g {:src :mentions}))
        mentions (mapv #(:val (get-node current-state {:mention %})) lmentions)]
    (set mentions)))

(defn find-all-stories
  "Finds all stories in graph and returns map with the id of the story
   (creation timestamp) as key and the story node itself as value."
  [current-state]
  (let [g (:graph current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :stories}))
        stories (into {} (mapv (fn [id] [id (get-entry current-state id)]) story-ids))]
    stories))

(defn find-all-habits
  "Finds all habits in graph and returns map with the id of the story
   (creation timestamp) as key and the habit node itself as value."
  [current-state]
  (let [g (:graph current-state)
        habit-ids (mapv :dest (uc/find-edges g {:src :habits}))]
    (mapv (fn [id] (entry-w-story current-state (get-entry current-state id))) habit-ids)))

(defn find-all-sagas
  "Finds all :saga entries in graph and returns map with the id of the saga
   (creation timestamp) as key and the saga node itself as value."
  [current-state]
  (let [g (:graph current-state)
        saga-ids (mapv :dest (uc/find-edges g {:src :sagas}))
        sagas (into {} (mapv (fn [id] [id (get-entry current-state id)]) saga-ids))]
    sagas))

(defn find-all-stories2
  "Finds all stories in graph and returns list."
  [current-state]
  (let [g (:graph current-state)
        sagas (find-all-sagas current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :stories}))
        xf (fn [id]
             (let [story (get-entry current-state id)
                   saga (get sagas (:linked_saga story))
                   story (assoc-in story [:saga] saga)]
               (merge story (:story_cfg story))))]
    (mapv xf story-ids)))

(defn find-all-sagas2
  "Finds all stories in graph and returns list."
  [current-state]
  (let [g (:graph current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :sagas}))]
    (mapv #(let [saga (get-entry current-state %)]
             (merge saga (:saga_cfg saga)))
          story-ids)))

(defn find-all-briefings
  "Finds all briefings in graph and returns map with the day as key and the
   briefing node id as value."
  [current-state]
  (let [g (:graph current-state)
        briefing-ids (mapv :dest (uc/find-edges g {:src :briefings}))
        briefings (into {} (mapv (fn [id]
                                   (let [entry (get-entry current-state id)
                                         day (-> entry :briefing :day)]
                                     [day id]))
                                 briefing-ids))]
    briefings))

(defn comments-linked-for-entry
  "Enrich entry with comments and linked entries."
  [graph]
  (fn [entry]
    (let [ts (:timestamp entry)]
      (when ts
        (-> entry
            (get-comments graph ts)
            (get-linked-entries graph ts))))))

(defn get-filtered [current-state query]
  (let [n (:n query 20)
        g (:graph current-state)
        entry-mapper (fn [entry] [(:timestamp entry) entry])
        entries (take n (filter (entries-filter-fn query current-state)
                                (extract-sorted-entries current-state query)))
        comment-timestamps (set (apply concat (mapv :comments entries)))
        linked-timestamps (apply set/union
                                 (mapv #(set (:linked_entries_list %))
                                       entries))
        linked (mapv #(get-entry current-state %) linked-timestamps)
        comments-linked (comments-linked-for-entry g)
        linked (mapv comments-linked linked)
        comments (mapv #(get-entry current-state %) comment-timestamps)
        entry-tuples (concat (mapv entry-mapper entries)
                             (mapv entry-mapper linked)
                             (mapv entry-mapper comments))
        timestamps (vec (into (sorted-set-by >)
                              (filter identity (mapv :timestamp entries))))]
    {:entries      timestamps
     :entries-map  (into {} (filter #(identity (first %)) entry-tuples))
     :entries-list (mapv comments-linked entries)}))

(defn get-filtered2 [current-state query]
  (let [n (:n query 20)
        pvt (:pvt query)
        g (:graph current-state)
        entries (take n (filter (entries-filter-fn query current-state)
                                (extract-sorted-entries current-state query)))
        comments-linked (comments-linked-for-entry g)
        pvt-filter (um/pvt-filter (:options current-state))
        entries (mapv comments-linked entries)]
    (if pvt
      entries
      (filter pvt-filter entries))))

(defn get-filtered-lazy [current-state query]
  (let [g (:graph current-state)
        entries (filter (entries-filter-fn query current-state)
                        (lazy-seq (extract-sorted-entries current-state query)))
        comments-linked (comments-linked-for-entry g)]
    (map comments-linked entries)))

(defn query-fn [{:keys [current-state put-fn]}]
  (let [progress (:startup-progress current-state)]
    (put-fn [:startup/progress progress])
    (when (= 1 (:graph progress))
      (put-fn [:sync/start-imap])))
  {})

(System/currentTimeMillis)
