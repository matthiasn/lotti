(ns meins.common.utils.misc
  (:require [clojure.set :as set]
            [clojure.string :as s]
            [meins.common.specs :as specs]
            [taoensso.timbre :refer [debug info]]))

(defn duration-string
  "Format duration string from seconds."
  [seconds]
  (let [hours (int (/ seconds 3600))
        seconds (rem seconds 3600)
        min (int (/ seconds 60))
        sec (int (rem seconds 60))]
    (s/trim
      (str (when (pos? hours) (str hours "h "))
           (when (pos? min) (str min "m "))
           (when (pos? sec) (str sec "s"))))))

(defn lower-case [str]
  (if str (s/lower-case str) ""))

(defn pvt-filter
  "Filter for entries considered private."
  [options]
  (fn [entry]
    (let [tags (set (map lower-case (:tags entry)))
          private-tags (:pvt-hashtags options)
          hashtags (:hashtags options)
          only-pvt-tags (set/difference private-tags hashtags)
          matched (set/intersection tags only-pvt-tags)
          pvt-cfg (or (:pvt (:custom_field_cfg entry))
                      (:pvt (:habit entry))
                      (-> entry :story :story_cfg :pvt)
                      (-> entry :story :saga :saga_cfg :pvt)
                      (:pvt (:dashboard_cfg entry)))]
      (and (empty? matched)
           (not pvt-cfg)))))

(defn suggestions
  "Renders suggestions for hashtags or mentions if either occurs before the
   current caret position. It does so by getting the selection from the DOM API,
   which can be used to determine the position and a string before that
   position, then finding either a hashtag or mention fragment right at the end
   of that substring. For these, auto-suggestions are displayed, which are
   entities that begin with the tag fragment before the caret position. When any
   of the suggestions are clicked, the fragment will be replaced with the
   clicked item."
  [key-prefix filtered-tags current-tag tag-replace-fn css-class]
  (when (seq filtered-tags)
    [:div.suggestions
     [:div.suggestions-list
      (for [tag filtered-tags]
        ^{:key (str key-prefix tag)}
        [:div {:on-click #(tag-replace-fn current-tag tag)}
         [:span {:class css-class} tag]])]]))

(defn double-ts-to-long
  [ts]
  (when (and ts (number? ts))
    (long (* ts 1000))))

(defn visit-timestamps
  "Parse arrival and departure timestamp as milliseconds since epoch."
  [entry]
  (let [departure-ts (let [ms (double-ts-to-long (:departure_timestamp entry))]
                       (when (specs/possible-timestamp? ms) ms))]
    {:arrival_ts   (double-ts-to-long (:arrival_timestamp entry))
     :departure_ts departure-ts}))

(defn count-words
  "Naive implementation of a wordcount function."
  [entry]
  (if-let [text (:md entry)]
    (count (filter seq (s/split text #"\s")))
    0))

(defn count-words-formatted
  "Generate wordcount string."
  [entry]
  (let [cnt (count-words entry)]
    (when (> cnt 20)
      (str cnt " words"))))

(defn deep-merge
  "Deep merge for multiple maps."
  [& maps]
  (let [maps (filter identity maps)]
    (when (seq maps)
      (apply (fn m [& maps]
               (if (every? map? maps)
                 (apply merge-with m maps)
                 (apply (fn [_ b] b) maps)))
             maps))))

(defn clean-entry
  "Removes keys from entry that are not meant to be persisted."
  [entry]
  (-> entry
      (dissoc :comments)
      (dissoc :new-entry)
      (dissoc :linked)
      (dissoc :linked-cnt)
      (dissoc :linked_cnt)
      (dissoc :last_saved)
      (dissoc :vclock)
      (dissoc :story)
      (update-in [:task] dissoc :due)
      (update-in [:tags] set)
      (dissoc :editor-state)
      (dissoc :editor_state)
      (dissoc :pomodoro-running)
      (dissoc :pomodoro_running)
      (dissoc :linked-entries-list)
      (dissoc :linked_entries_list)))

(defn search-from-cfg [state] (select-keys (:query-cfg state) #{:queries}))

(defn cleaned-queries [state]
  (->> state
       :query-cfg
       :queries
       (map (fn [[k v]] [k (dissoc v :editor-state)]))
       (into {})))

(defn idxd [coll]
  (map-indexed (fn [idx v] [idx v]) coll))

(defn connect [from to]
  [:cmd/route {:from from
               :to   to}])

(defn imap-to-app-cfg [imap-cfg]
  (let [server-cfg (:server imap-cfg)
        write-folder (-> imap-cfg :sync :read first second :mailbox)
        read-folder (-> imap-cfg :sync :write :mailbox)]
    {:server {:hostname (:host server-cfg)
              :port     (:port server-cfg)
              :username (:user server-cfg)
              :password (:password server-cfg)}
     :sync   {:write {:folder write-folder}
              :read  {:folder read-folder}}}))
