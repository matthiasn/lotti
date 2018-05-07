(ns meo.jvm.graph.query
  "this namespace manages interactions with the graph data structure, which
  holds all entries and their connections."
  (:require [ubergraph.core :as uc]
            [meo.jvm.fulltext-search :as ft]
            [clj-time.coerce :as ctc]
            [clj-time.format :as ctf]
            [clojure.string :as s]
            [clojure.set :as set]
            [taoensso.timbre :refer [info error warn debug]]
            [clojure.pprint :as pp]
            [matthiasn.systems-toolbox.component :as st]
            [clj-uuid :as uuid]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [camel-snake-kebab.core :refer [->snake_case]]
            [clj-time.core :as ct])
  (:import (org.joda.time DateTimeZone)))

;; TODO: migrate existing audio entries to use a different keyword
(defn summed-durations
  "Calculate time spent as tracked in custom fields."
  [entry]
  (let [custom-fields (:custom-fields entry)
        duration-secs (filter identity (mapv (fn [[k v]]
                                               (let [dur (:duration v)]
                                                 (if (= k "#audio")
                                                   0
                                                   (* 60 (or dur 0)))))
                                             custom-fields))]
    (apply + duration-secs)))

(def dtz (ct/default-time-zone))
(def fmt (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))
(defn parse [dt] (ctf/parse fmt dt))

(defn entries-filter-fn
  "Creates a filter function which ensures that all tags and mentions in the
   query are contained in the filtered entry or any of it's comments, and none
   of the not-tags. Also allows filtering per day."
  [q g]
  (fn [entry]
    (let [local-fmt (ctf/with-zone (ctf/formatters :year-month-day)
                                   (ct/default-time-zone))
          entry-day (ctf/unparse local-fmt (ctc/from-long (:timestamp entry)))
          q-day (:date-string q)
          day-match? (or (= q-day entry-day)
                         (when-let [for-day (:for-day entry)]
                           (= q-day (subs for-day 0 10))))

          q-timestamp (:timestamp q)
          q-ts-match? (= q-timestamp (str (:timestamp entry)))

          q-country (:country q)
          q-cc-match? (= q-country (-> entry :geoname :country-code))

          q-tags (set (mapv s/lower-case (:tags q)))
          q-not-tags (set (mapv s/lower-case (:not-tags q)))
          q-mentions (set (mapv s/lower-case (:mentions q)))

          tags (set (mapv s/lower-case (:tags entry)))
          entry-comments (mapv #(uc/attrs g %) (:comments entry))
          entry-comments-tags (apply set/union (mapv :tags entry-comments))
          tags (set (mapv s/lower-case (set/union tags entry-comments-tags)))

          mentions (set (mapv s/lower-case (:mentions entry)))
          entry-comments-mentions (apply set/union (mapv :mentions entry-comments))
          mentions (set (mapv s/lower-case (set/union mentions entry-comments-mentions)))

          story-match? (if-let [story (:story q)]
                         (or (= story (:primary-story entry))
                             (= story (:timestamp entry)))
                         true)
          starred-match? (if (:starred q) (:starred entry) true)
          opts (:opts q)
          opts-match?
          (cond
            (contains? opts ":started")
            (when (contains? tags "#task")
              (let [nodes (into [entry] entry-comments)
                    filter-fn (fn [n]
                                (let [completed (:completed-time n)]
                                  (or (when completed (pos? completed))
                                      (pos? (summed-durations n)))))
                    started (filter filter-fn nodes)]
                (seq started)))

            (contains? opts ":waiting")
            (when (contains? tags "#habit")
              (when-let [active-from (get-in entry [:habit :active-from])]
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
            (= :story (:entry-type entry))

            (contains? opts ":no-story")
            (not (:primary-story entry))

            (contains? opts ":predicted-stories")
            (and (not (:primary-story entry))
                 (not (:briefing entry))
                 (not (contains? (:tags entry) "#briefing"))
                 (not (= :saga (:entry-type entry))))

            (contains? opts ":saga")
            (= :saga (:entry-type entry))

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
                      opts-match?)]
      match?)))

(defn get-comments
  "Extract all comments for entry."
  [entry g ts]
  (let [edges (uc/find-edges g {:dest ts :relationship :COMMENT})
        comment-ids (->> (flatten edges)
                         (remove :mirror?)
                         (mapv :src)
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
        t-matched (mapv (mapper :tag) (mapv s/lower-case (:tags query)))
        nt-matched (mapv (mapper :tag) (mapv s/lower-case (:not-tags query)))
        ntp-matched (mapv (mapper :ptag) (mapv s/lower-case (:not-tags query)))
        pt-matched (mapv (mapper :ptag) (mapv s/lower-case (:tags query)))
        m-matched (mapv (mapper :mention) (mapv s/lower-case (:mentions query)))
        match-sets (filter seq (concat t-matched pt-matched m-matched))
        matched (if (seq match-sets) (apply set/intersection match-sets) #{})
        not-matched (apply set/union (filter seq (concat nt-matched ntp-matched)))]
    (set/difference matched not-matched)))

(defn get-nodes-for-day
  "Extract matching timestamps for query."
  [g query]
  (let [dt (ctf/parse (ctf/formatters :year-month-day) (:date-string query))]
    (set (mapv :dest (uc/find-edges g {:src          {:type  :timeline/day
                                                      :year  (ct/year dt)
                                                      :month (ct/month dt)
                                                      :day   (ct/day dt)}
                                       :relationship :DATE})))))

(defn get-linked-nodes
  "Find all linked nodes for entry."
  [g query]
  (let [for-entry (Long/parseLong (:linked query))
        linked (->> (flatten (uc/find-edges g {:src for-entry :relationship :LINKED}))
                    (mapv :dest)
                    (sort))]
    (set linked)))

(defn get-briefing-for-day
  "Extract matching timestamps for query."
  [g query]
  (when-let [briefing-day (:briefing query)]
    (let [dt (ctf/parse (ctf/formatters :year-month-day) briefing-day)
          day-node {:type  :timeline/day
                    :year  (ct/year dt)
                    :month (ct/month dt)
                    :day   (ct/day dt)}]
      (set (mapv :dest (uc/find-edges g {:src          day-node
                                         :relationship :BRIEFING}))))))

(defn get-connected-nodes
  "Extract matching timestamps for query."
  [g node]
  (set (mapv :dest (uc/find-edges g {:src node}))))

(defn get-linked-entries
  "Extract all linked entries for entry, including their comments."
  [entry g n sort-by-upvotes?]
  (let [linked (->> (flatten (uc/find-edges g {:src n :relationship :LINKED}))
                    (mapv :dest)
                    (sort))]
    (merge entry {:linked-entries-list (vec linked)})))

(defn extract-sorted-entries
  "Extracts nodes and their properties in descending timestamp order by looking
   for node by mapping over the sorted set and extracting attributes for each
   node.
   Warns when node not in graph. (debugging, should never happen)"
  [state query]
  (let [g (:graph state)
        n (:n query 20)
        mapper-fn (fn [n]
                    (if (uc/has-node? g n)
                      (-> (uc/attrs g n)
                          (get-comments g n)
                          (get-linked-entries g n false))
                      (debug "extract-sorted-entries can't find node: " n)))
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
                      (:date-string query)
                      (get-nodes-for-day g query)

                      ; set with starred entries
                      (:starred query)
                      (get-connected-nodes g :starred)

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
                      :else (take (+ n 100) (:sorted-entries state)))
        matched-ids (if (contains? opts ":predicted-stories")
                      matched-ids
                      (sort-fn matched-ids))
        matched-entries (mapv mapper-fn matched-ids)
        matched-entries (filter #(or (:briefing query)
                                     (not (:briefing %))) matched-entries)
        parent-ids (filter identity (mapv :comment-for matched-entries))
        parents (mapv mapper-fn parent-ids)]
    (flatten [matched-entries parents])))

(defn extract-sorted2
  "Extracts nodes and their properties in descending timestamp order by looking
   for node by mapping over the sorted set and extracting attributes for each
   node.
   Warns when node not in graph. (debugging, should never happen)"
  [state query]
  (let [g (:graph state)
        n (:n query 20)
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
                      (:date-string query)
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
    matched-ids))

(defn find-all-hashtags
  "Finds all hashtags used in entries by finding the edges that originate from
   the :hashtags node. Merges the tags in the :pvt-displayed key of the config
   files, as those are the private keys that should be available in the
   autosuggestions."
  [current-state]
  (let [g (:graph current-state)
        ltags (mapv #(-> % :dest :tag) (uc/find-edges g {:src :hashtags}))]
    (->> ltags
         (mapv (fn [lt]
                 (let [tag (:val (uc/attrs g {:tag lt}))
                       cnt (count (uc/find-edges g {:src {:tag lt}}))]
                   [tag cnt])))
         (sort-by second)
         reverse
         (mapv first))))

(defn find-all-pvt-hashtags
  "Finds all private hashtags. Private hashtags are either those used
   exclusively in entries marked private, or the tags in the config key
   :pvt-tags."
  [current-state]
  (let [cfg (:cfg current-state)
        g (:graph current-state)
        ltags (mapv #(-> % :dest :ptag) (uc/find-edges g {:src :pvt-hashtags}))
        tags (mapv #(:val (uc/attrs g {:ptag %})) ltags)]
    (disj (set/union (set tags) (:pvt-tags cfg)) "#new" "#import")))

(defn find-all-mentions
  "Finds all hashtags used in entries by finding the edges that originate from
   the :hashtags node."
  [current-state]
  (let [g (:graph current-state)
        lmentions (mapv #(-> % :dest :mention)
                        (uc/find-edges g {:src :mentions}))
        mentions (mapv #(:val (uc/attrs g {:mention %})) lmentions)]
    (set mentions)))

(defn find-all-stories
  "Finds all stories in graph and returns map with the id of the story
   (creation timestamp) as key and the story node itself as value."
  [current-state]
  (let [g (:graph current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :stories}))
        stories (into {} (mapv (fn [id] [id (uc/attrs g id)]) story-ids))]
    stories))

(defn find-all-sagas
  "Finds all :saga entries in graph and returns map with the id of the saga
   (creation timestamp) as key and the saga node itself as value."
  [current-state]
  (let [g (:graph current-state)
        saga-ids (mapv :dest (uc/find-edges g {:src :sagas}))
        sagas (into {} (mapv (fn [id] [id (uc/attrs g id)]) saga-ids))]
    sagas))

(defn find-all-stories2
  "Finds all stories in graph and returns list."
  [current-state]
  (let [g (:graph current-state)
        sagas (find-all-sagas current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :stories}))
        xf (fn [id]
             (let [story (uc/attrs g id)
                   saga (get sagas (:linked-saga story))
                   story (assoc-in story [:linked-saga] saga)]
               (transform-keys ->snake_case story)))]
    (mapv xf story-ids)))

(defn find-all-sagas2
  "Finds all stories in graph and returns list."
  [current-state]
  (let [g (:graph current-state)
        story-ids (mapv :dest (uc/find-edges g {:src :sagas}))]
    (mapv #(transform-keys ->snake_case (uc/attrs g %)) story-ids)))

(defn find-all-briefings
  "Finds all briefings in graph and returns map with the day as key and the
   briefing node id as value."
  [current-state]
  (let [g (:graph current-state)
        briefing-ids (mapv :dest (uc/find-edges g {:src :briefings}))
        briefings (into {} (mapv (fn [id]
                                   (let [entry (uc/attrs g id)
                                         day (-> entry :briefing :day)]
                                     [day id]))
                                 briefing-ids))]
    briefings))

(defn comments-linked-for-entry
  "Enrich entry with comments and linked entries."
  [graph sort-by-upvotes?]
  (fn [entry]
    (let [ts (:timestamp entry)]
      (when ts
        (-> entry
            (get-comments graph ts)
            (get-linked-entries graph ts sort-by-upvotes?))))))

(defn get-filtered [current-state query]
  (let [n (:n query 20)
        g (:graph current-state)
        entry-mapper (fn [entry] [(:timestamp entry) entry])
        entries (take n (filter (entries-filter-fn query g)
                                (extract-sorted-entries current-state query)))
        comment-timestamps (set (apply concat (mapv :comments entries)))
        linked-timestamps (apply set/union
                                 (mapv #(set (:linked-entries-list %))
                                       entries))
        linked (mapv #(uc/attrs g %) linked-timestamps)
        comments-linked (comments-linked-for-entry g false)
        linked (mapv comments-linked linked)
        comments (mapv #(uc/attrs g %) comment-timestamps)
        entry-tuples (concat (mapv entry-mapper entries)
                             (mapv entry-mapper linked)
                             (mapv entry-mapper comments))
        timestamps (vec (into (sorted-set-by >)
                              (filter identity (mapv :timestamp entries))))]
    {:entries      timestamps
     :entries-map  (into {} (filter #(identity (first %)) entry-tuples))
     :entries-list entries}))

(defn find-entry
  "Find single entry."
  [{:keys [current-state msg-payload]}]
  (let [g (:graph current-state)
        ts (:timestamp msg-payload)]
    (if (uc/has-node? g ts)
      (let [comments-linked-mapper (comments-linked-for-entry g false)
            entry (comments-linked-mapper (uc/attrs g ts))]
        {:emit-msg (when entry [:entry/found entry])})
      (warn "cannot find node: " ts))))

(defn run-query [current-state]
  (fn [[query-id query]]
    (let [res (get-filtered current-state query)]
      [query-id res])))

(defn query-fn
  "Runs all queries in request, sends back to client, with all entry maps
   for the individual queries merged into one."
  [{:keys [current-state msg-payload put-fn]}]
  (put-fn [:startup/progress (:startup-progress current-state)])
  (when (= 1 (:startup-progress current-state))
    (let [queries (:queries msg-payload)
          start-ts (System/nanoTime)
          res-mapper (run-query current-state)
          res (mapv res-mapper queries)
          res (reduce (fn [acc [k v]]
                        (-> acc
                            (update-in [:entries-map] merge (:entries-map v))
                            (assoc-in [:entries k] (:entries v))))
                      {:entries-map {} :entries {}}
                      res)
          ms (/ (- (System/nanoTime) start-ts) 1000000)
          story-predict (select-keys (:story-predictions current-state)
                                     (keys (:entries-map res)))
          res2 {:duration-ms   (pp/cl-format nil "~,2f ms" ms)
                :story-predict story-predict}]
      (debug queries)
      (info "queries took" (:duration-ms res2))
      {:emit-msg [:state/new (merge res res2)]})))
