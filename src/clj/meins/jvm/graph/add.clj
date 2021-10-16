(ns meins.jvm.graph.add
  "Functions for adding new entries."
  (:require [clj-time.coerce :as c]
            [clj-time.core :as ct]
            [clj-time.format :as ctf]
            [clojure.set :as set]
            [meins.common.utils.misc :as u]
            [meins.jvm.datetime :as dt]
            [meins.jvm.graph.query :as gq]
            [meins.jvm.metrics :as mt]
            [metrics.timers :as tmr]
            [taoensso.timbre :refer [debug error info warn]]
            [ubergraph.core :as uc]))

(defn add-entry [state entry]
  (let [ts (:timestamp entry)]
    (assoc-in state [:entries-map ts] entry)))

(defn update-entry [state entry]
  (let [ts (:timestamp entry)]
    (update-in state [:entries-map ts] merge entry)))

(defn add-hashtags
  "Add hashtag edges to graph for a new entry. When a hashtag exists already,
   an edge to the existing node will be added, otherwise a new hashtag node will
   be created.
   When any of the private tags occur, the entry is considered private, and all
   the tags that are not known to be public will be added to the private tags
   in the graph."
  [current-state entry]
  (let [graph (:graph current-state)
        cfg (:cfg current-state)
        tags (set/union (set (:perm_tags entry)) (set (:tags entry)))
        pvt-tags (set/union (:pvt-displayed cfg) (:pvt-tags cfg))
        pvt-entry? (seq (set/intersection tags pvt-tags))
        comment-for (:comment_for entry)
        tag-add-fn
        (fn [g tag]
          (let [ltag (u/lower-case tag)
                public-tag? (uc/has-node? graph {:tag ltag})
                pvt-tag? (and pvt-entry?
                              (not public-tag?))
                ht-parent (if pvt-tag? :pvt-hashtags :hashtags)
                tag-type (if pvt-tag? :ptag :tag)]
            (-> g
                (uc/add-nodes ht-parent)
                (uc/add-nodes-with-attrs [{tag-type ltag} {:val tag}])
                (uc/add-edges
                  [{tag-type ltag} (:timestamp entry) {:relationship :CONTAINS}]
                  (when comment-for
                    [{tag-type ltag} comment-for {:relationship :CONTAINS}])
                  [ht-parent {tag-type ltag} {:relationship :IS}]))))]
    (assoc-in current-state [:graph] (reduce tag-add-fn graph tags))))

(defn add-mentions
  "Add mention edges to graph for a new entry. When a mentioned person exists
   already, an edge to the existing node will be added, otherwise a new hashtag
   node will be created."
  [graph entry]
  (let [mentions (:mentions entry)]
    (reduce
      (fn [acc mention]
        (let [lmention (u/lower-case mention)]
          (-> acc
              (uc/add-nodes :mentions)
              (uc/add-nodes-with-attrs [{:mention lmention} {:val mention}])
              (uc/add-edges
                [{:mention lmention} (:timestamp entry) {:relationship :CONTAINS}]
                [:mentions {:mention lmention} {:relationship :IS}]))))
      graph
      mentions)))

(defn add-timeline-tree
  "Adds graph nodes for year, month and day of entry and connects those if they
   don't exist. In any case, connects new entry node to the entry node of the
   matching :timeline/day node."
  [state entry k]
  (let [g (:graph state)
        dt (dt/dt-tz (k entry) (:timezone entry))
        year (ct/year dt)
        month (ct/month dt)
        year-node {:type :timeline/year :year year}
        month-node {:type :timeline/month :year year :month month}
        day-node {:type :timeline/day :year year :month month :day (ct/day dt)}]
    (assoc-in state [:graph] (-> g
                                 (uc/add-nodes year-node month-node day-node)
                                 (uc/add-edges
                                   [year-node month-node]
                                   [month-node day-node]
                                   [day-node
                                    (:timestamp entry)
                                    {:relationship :DATE}])))))

(defn add-geoname [state entry]
  (let [geoname (:geoname entry)]
    (if (and geoname (:latitude entry))
      (let [g (:graph state)
            dt (dt/local-dt (:timestamp entry))
            year (ct/year dt)
            month (ct/month dt)
            country {:type :geoname/cc :country-code (:country-code geoname)}
            geoname {:type :geoname/geoname :geoname geoname}
            day-node {:type :timeline/day :year year :month month :day (ct/day dt)}]
        (assoc-in state [:graph] (-> g
                                     (uc/add-nodes :countries country)
                                     (uc/add-nodes :geonames geoname)
                                     (uc/add-edges
                                       [:countries country]
                                       [:geonames geoname]
                                       [day-node country {:relationship :VISITED}]
                                       [day-node geoname {:relationship :VISITED}]))))
      state)))

(defn add-adjusted-ts
  "Adds links to timeline nodes when when entry date and time were adjusted."
  [state entry]
  (let [g (:graph state)]
    (if-let [adjusted-ts (:adjusted_ts entry)]
      (let [dt (c/from-long adjusted-ts)
            year (ct/year dt)
            month (ct/month dt)
            year-node {:type :timeline/year :year year}
            month-node {:type :timeline/month :year year :month month}
            day-node {:type :timeline/day :year year :month month :day (ct/day dt)}]
        (assoc-in state [:graph] (-> g
                                     (uc/add-nodes year-node month-node day-node)
                                     (uc/add-edges
                                       [year-node month-node]
                                       [month-node day-node]
                                       [day-node
                                        (:timestamp entry)
                                        {:relationship :DATE}]))))
      state)))

(defn add-parent-ref [graph entry]
  (if-let [comment-for (:comment_for entry)]
    (uc/add-edges graph
                  [(:timestamp entry) comment-for {:relationship :COMMENT}])
    graph))

(defn add-linked
  "Add mention edges to graph for a new entry. When a mentioned person exists
   already, an edge to the existing node will be added, otherwise a new hashtag
   node will be created."
  [graph entry]
  (let [linked-entries (:linked_entries entry)]
    (reduce (fn [acc linked-entry]
              (let [with-linked (if (uc/has-node? acc linked-entry)
                                  acc (uc/add-nodes acc linked-entry))]
                (uc/add-edges with-linked
                              [(:timestamp entry) linked-entry
                               {:relationship :LINKED}])))
            graph
            linked-entries)))

(defn unlink [{:keys [current-state msg-payload put-fn]}]
  (let [rm-edges #(uc/remove-edges % (vec msg-payload))
        new-state (update-in current-state [:graph] rm-edges)]
    (put-fn [:schedule/new {:message [:gql/run-registered]
                            :timeout 10
                            :id      :saved-entry}])
    {:new-state new-state}))

(defn add-linked-visit [state entry]
  (let [{:keys [arrival-ts departure-ts]} (u/visit-timestamps entry)]
    (if departure-ts
      (let [ts (:timestamp entry)
            ts-dt (c/from-long ts)
            g (:graph state)
            q {:date_string (ctf/unparse (ctf/formatters :year-month-day) ts-dt)}
            same-day-entry-ids (gq/get-nodes-for-day g q)
            same-day-entries (mapv #(gq/get-entry state %) same-day-entry-ids)
            filter-fn (fn [other-entry]
                        (let [other-ts (:timestamp other-entry)]
                          (and (< other-ts departure-ts)
                               (> other-ts arrival-ts))))
            matching-entries (filterv filter-fn same-day-entries)
            matching-entry-ids (mapv :timestamp matching-entries)
            reducing-fn (fn [g match]
                          (uc/add-edges g [ts match {:relationship :LINKED}]))
            updated-g (reduce reducing-fn g matching-entry-ids)]
        (assoc-in state [:graph] updated-g))
      state)))

(defn remove-unused-tags
  "Checks for orphan tags and removes them. Orphan tags would occur when
   deleting the last entry that contains a specific tag. Takes the state, a set
   of tags, and the tag type, such as :tags or :mentions."
  [graph tags k]
  (reduce
    (fn [g tag]
      (let [ltag (u/lower-case tag)]
        (if (and (empty? (uc/find-edges g {:src {k ltag} :relationship :CONTAINS}))
                 (not (contains? #{"#new" "#import"} tag)))
          (uc/remove-nodes g {k ltag})
          g)))
    graph
    tags))

(defn remove-node [current-state ts]
  (if-let [entry (gq/get-entry current-state ts)]
    (-> current-state
        (update-in [:graph] uc/remove-nodes ts)
        (update-in [:sorted-entries] disj ts)
        (update-in [:graph] remove-unused-tags (:mentions entry) :mention)
        (update-in [:graph] remove-unused-tags (:tags entry) :tag)
        (update-in [:graph] remove-unused-tags (:tags entry) :ptag))
    current-state))

(defn add-location [graph entry]
  (if (:location entry)
    (-> graph
        (uc/add-nodes :locations)
        (uc/add-edges [:locations (:timestamp entry)]))
    graph))

(defn add-briefing [graph entry]
  (if-let [briefing-day (-> entry :briefing :day)]
    (let [dt (ctf/parse (ctf/formatters :year-month-day) briefing-day)
          year (ct/year dt)
          month (ct/month dt)
          day (ct/day dt)
          day-node {:type :timeline/day :year year :month month :day day}]
      (-> graph
          (uc/add-nodes :briefings day-node)
          (uc/add-edges [day-node (:timestamp entry) {:relationship :BRIEFING}]
                        [:briefings (:timestamp entry)])))
    graph))

(defn add-story [graph entry]
  (if (= (:entry_type entry) :story)
    (-> graph
        (uc/add-nodes :stories)
        (uc/add-edges [:stories (:timestamp entry)]))
    graph))

(defn add-saga [graph entry]
  (if (= (:entry_type entry) :saga)
    (-> graph
        (uc/add-nodes :saga)
        (uc/add-edges [:sagas (:timestamp entry)]))
    graph))

(defn add-starred [graph entry]
  (if (:starred entry)
    (-> graph
        (uc/add-nodes :starred)
        (uc/add-edges [:starred (:timestamp entry)]))
    (uc/remove-edges graph [(:timestamp entry) :starred])))

(defn add-habit [graph entry]
  (if (or (= :habit (:entry-type entry))
          (= :habit (:entry_type entry)))
    (-> graph
        (uc/add-nodes :habits)
        (uc/add-edges [:habits (:timestamp entry)]))
    graph))

(defn add-flagged [graph entry]
  (if (:flagged entry)
    (-> graph
        (uc/add-nodes :flagged)
        (uc/add-edges [:flagged (:timestamp entry)]))
    (uc/remove-edges graph [(:timestamp entry) :flagged])))

(defn add-completion [g entry tsk]
  (if-let [completion-ts (tsk (:task entry))]
    (let [dt (ctf/parse dt/dt-completion-fmt completion-ts)
          day-node {:type  :timeline/day
                    :year  (ct/year dt)
                    :month (ct/month dt)
                    :day   (ct/day dt)}]
      (uc/add-edges g [day-node
                       (:timestamp entry)
                       {:relationship :DATE}]))
    g))

(defn add-done [g k tsk entry]
  (if (get-in entry [:task k])
    (let [g (uc/add-nodes g k)
          g (uc/add-edges g [k (:timestamp entry)])]
      (add-completion g entry tsk))
    g))

(defn add-story-set [current-state entry]
  (if-let [linked-story (:primary_story entry)]
    (let [ts (:timestamp entry)
          path [:sorted-story-entries linked-story]
          entries-set (into (sorted-set) (get-in current-state path))]
      (assoc-in current-state path (conj entries-set ts)))
    current-state))

(defn add-tasks-set [current-state entry]
  (if (:task entry)
    (let [ts (:timestamp entry)
          path [:sorted-tasks]
          entries-set (into (sorted-set) (get-in current-state path))]
      (assoc-in current-state path (conj entries-set ts)))
    current-state))

(defn add-node
  "Adds node to both graph and the sorted set, which maintains the entries
   sorted by timestamp."
  [current-state entry cfg]
  (let [timer-id ["graph" "add" (name (or (:entry-type entry) "entry"))]
        started-timer (mt/start-timer timer-id)
        ts (:timestamp entry)
        {:keys [clean-tags]} cfg
        old-entry (gq/get-entry current-state ts)
        merged (merge old-entry entry)
        old-tags (:tags old-entry)
        old-mentions (:mentions old-entry)
        remove-tag-edges (fn [g tags k]
                           (let [reducing-fn
                                 (fn [g ltag] (uc/remove-edges g [ts {k ltag}]))]
                             (reduce reducing-fn g (map u/lower-case tags))))
        media-tags (set (filter identity [(when (:img_file entry) "#photo")
                                          (when (:audio-file entry) "#audio")
                                          (when (:video entry) "#video")]))
        new-entry (update-in merged [:tags] #(set/union (set %) media-tags))
        res (-> current-state
                (add-entry new-entry)
                (cond-> (and clean-tags (not= (:tags entry) old-tags))
                        (-> (update-in [:graph] remove-tag-edges old-tags :tag)
                            (update-in [:graph] remove-tag-edges old-tags :ptag)
                            (update-in [:graph] remove-unused-tags old-tags :tag)))
                (cond-> (not= (:tags entry) old-tags)
                        (add-hashtags new-entry))
                (cond-> (not= (:mentions entry) (:mentions old-entry))
                        (-> (update-in [:graph] remove-tag-edges old-mentions :mention)
                            (update-in [:graph] remove-unused-tags old-mentions :mention)
                            (update-in [:graph] add-mentions new-entry)))
                (cond-> (not= (:linked_entries entry) (:linked_entries old-entry))
                        (update-in [:graph] add-linked new-entry))
                (cond-> (not= (u/visit-timestamps entry) (u/visit-timestamps old-entry))
                        (update add-linked-visit new-entry))
                (cond-> (not= (:primary_story entry) (:primary_story old-entry))
                        (add-story-set new-entry))
                (cond-> (not= (:task entry) (:task old-entry))
                        (add-tasks-set new-entry))
                (cond-> (not old-entry)
                        (add-timeline-tree new-entry :timestamp))
                (cond-> (:adjusted_ts new-entry)
                        (add-timeline-tree new-entry :adjusted_ts))
                (add-geoname new-entry)
                (add-adjusted-ts new-entry)
                (update-in [:graph] add-parent-ref new-entry)
                (update-in [:graph] add-story new-entry)
                (update-in [:graph] add-saga new-entry)
                (update-in [:graph] add-habit new-entry)
                (update-in [:graph] add-starred new-entry)
                (update-in [:graph] add-flagged new-entry)
                (update-in [:graph] add-done :done :completion_ts new-entry)
                (update-in [:graph] add-done :closed :closed_ts new-entry)
                (update-in [:graph] add-location new-entry)
                (update-in [:graph] add-briefing new-entry)
                (update-in [:sorted-entries] conj ts))]
    (tmr/stop started-timer)
    res))
