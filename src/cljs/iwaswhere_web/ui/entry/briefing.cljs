(ns iwaswhere-web.ui.entry.briefing
  (:require [matthiasn.systems-toolbox.component :as st]
            [iwaswhere-web.ui.charts.pomodoros :as p]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [iwaswhere-web.charts.data :as cd]
            [iwaswhere-web.ui.charts.common :as cc]
            [iwaswhere-web.utils.misc :as u]
            [clojure.pprint :as pp]
            [iwaswhere-web.ui.entry.actions :as a]
            [iwaswhere-web.utils.parse :as up]
            [clojure.string :as s]
            [iwaswhere-web.ui.entry.utils :as eu]
            [reagent.core :as r]))

(defn time-by-stories-list
  "Render list of times spent on individual stories, plus the total."
  [day-stats local]
  (let [stories (subscribe [:stories])
        books (subscribe [:books])
        book-filter (fn [[k v]]
                      (if-let [selected (:selected @local)]
                        (let [story (get @stories k)]
                          (= selected (:linked-book story)))
                        true))
        story-name-mapper (fn [[k v]]
                            (let [s (or (:story-name (get @stories k)) "none")]
                              [s v]))]
    (fn [day-stats local]
      (let [stories @stories
            books @books
            dur (u/duration-string (:total-time day-stats))
            date (:date-string day-stats)
            time-by-story (:time-by-story day-stats)
            time-by-story2 (->> day-stats
                                :time-by-story
                                (filter book-filter)
                                (map story-name-mapper)
                                (sort-by first))
            y-scale 0.0045]
        (when date
          [:table
           [:tbody
            [:tr [:th ""] [:th "story"] [:th "actual"]]
            (for [[story v] time-by-story2]
              (let [color (cc/item-color story)]
                ^{:key story}
                [:tr
                 [:td [:div.legend {:style {:background-color color}}]]
                 [:td [:strong story]]
                 [:td.time (u/duration-string v)]]))]])))))

(defn entry-compare
  "Compare by prio first, then by active-from."
  [k]
  (fn [x y]
    (let [prio-x (get-in x [k :priority] :X)
          prio-y (get-in y [k :priority] :X)
          c (compare prio-x prio-y)
          active-x (get-in x [k :active-from])
          active-y (get-in y [k :active-from])]
      (if (not= c 0) c (compare active-x active-y)))))

(defn open-entries-list
  "Renders table with open entries, such as started tasks and open habits."
  [tab-group qk k header put-fn]
  (let [cfg (subscribe [:cfg])
        results (subscribe [:results])
        options (subscribe [:options])
        entries-map (subscribe [:entries-map])
        entries-list
        (reaction
          (let [entries-map @entries-map
                sorter (entry-compare k)
                entries (->> (qk @results)
                             (map (fn [ts] (get entries-map ts)))
                             (sort sorter))
                conf (merge @cfg @options)]
            (if (:show-pvt @cfg)
              entries
              (filter (u/pvt-filter conf entries-map) entries))))]
    (fn open-entries-list-render [tab-group qk k header put-fn]
      (let [entries-list @entries-list]
        (when (seq entries-list)
          [:div
           [:table.habits
            [:tbody
             [:tr [:th ""] [:th header]]
             (for [entry entries-list]
               (let [ts (:timestamp entry)]
                 ^{:key ts}
                 [:tr {:on-click (up/add-search ts tab-group put-fn)}
                  [:td
                   (when-let [prio (-> entry k :priority)]
                     [:span.prio {:class prio} prio])]
                  [:td
                   [:strong (some-> entry
                                    :md
                                    (s/replace "#task" "")
                                    (s/replace "#habit" "")
                                    (s/replace "##" "")
                                    s/split-lines
                                    first)]]]))]]])))))

(defn started-tasks-list
  "Renders table with open entries, such as started tasks and open habits."
  [tab-group put-fn]
  (let [local (r/atom {:on-hold false})
        cfg (subscribe [:cfg])
        results (subscribe [:results])
        options (subscribe [:options])
        entries-map (subscribe [:entries-map])
        not-on-hold #(not (:on-hold (:task %)))
        on-hold-filter (fn [entry]
                         (let [on-hold (:on-hold (:task entry))]
                           (if (:on-hold @local)
                             on-hold
                             (not on-hold))))
        filter-btn (fn [fk]
                     [:span.filter {:class    (when (:on-hold @local) "current")
                                    :on-click #(swap! local update-in [:on-hold] not)}
                      (name fk)])
        entries-list (reaction
                       (let [entries-map @entries-map
                             sorter (entry-compare :task)
                             entries (->> (:started-tasks @results)
                                          (map (fn [ts] (get entries-map ts)))
                                          (filter on-hold-filter)
                                          (sort sorter))
                             conf (merge @cfg @options)]
                         (if (:show-pvt @cfg)
                           entries
                           (filter (u/pvt-filter conf entries-map) entries))))]
    (fn started-tasks-list-render [tab-group put-fn]
      (let [entries-list @entries-list]
        (when (seq entries-list)
          [:div.linked-tasks
           [:table.habits
            [:tbody
             [:tr
              [:th ""]
              [:th
               [:div
                "started tasks: "
                [filter-btn :on-hold]]]]
             (for [entry entries-list]
               (let [ts (:timestamp entry)]
                 ^{:key ts}
                 [:tr {:on-click (up/add-search ts tab-group put-fn)}
                  [:td
                   (when-let [prio (-> entry :task :priority)]
                     [:span.prio {:class prio} prio])]
                  [:td
                   [:strong (some-> entry
                                    :md
                                    (s/replace "#task" "")
                                    (s/replace "#habit" "")
                                    (s/replace "##" "")
                                    s/split-lines
                                    first)]]]))]]])))))

(defn open-linked-tasks-list
  "Show open tasks that are also linked with the briefing entry."
  [ts local local-cfg put-fn]
  (let [entry (:entry (eu/entry-reaction ts))
        cfg (subscribe [:cfg])
        results (subscribe [:results])
        options (subscribe [:options])
        stories (reaction (:stories @options))
        entries-map (subscribe [:entries-map])
        linked-filters {:open    (up/parse-search "#task ~#done ~#closed ~#backlog")
                        :done    (up/parse-search "#task #done")
                        :closed  (up/parse-search "#task #closed")
                        :backlog (up/parse-search "#task #backlog")}
        filter-btn (fn [fk]
                     [:span.filter {:class    (when (= fk (:filter @local)) "current")
                                    :on-click #(swap! local assoc-in [:filter] fk)}
                      (name fk)])]
    (fn open-linked-tasks-render [ts local local-cfg put-fn]
      (let [{:keys [tab-group query-id]} local-cfg
            linked-entries-set (into (sorted-set) (:linked-entries-list @entry))
            linked-mapper (u/find-missing-entry @entries-map put-fn)
            linked-entries (mapv linked-mapper linked-entries-set)
            conf (merge @cfg @options)
            linked-entries (if (:show-pvt conf)
                             linked-entries
                             (filter (u/pvt-filter conf @entries-map) linked-entries))
            current-filter (get linked-filters (:filter @local))
            filter-fn (u/linked-filter-fn @entries-map current-filter put-fn)
            book-filter (fn [entry]
                          (if-let [selected (:selected @local)]
                            (let [story (get @stories (:linked-story entry))]
                              (= selected (:linked-book story)))
                            true))
            active-filter (fn [t]
                            (let [active-from (-> t :task :active-from)
                                  current-filter (get linked-filters (:filter @local))]
                              (if (and active-from (= current-filter
                                                      (:open linked-filters)))
                                (let [from-now (.fromNow (js/moment active-from))]
                                  (s/includes? from-now "ago"))
                                true)))
            linked-entries (->> linked-entries
                                (filter filter-fn)
                                (filter book-filter)
                                (filter active-filter)
                                (sort-by #(or (-> % :task :priority) :X)))]
        [:div.linked-tasks
         [:table
          [:tbody
           [:tr [:th ""]
            [:th [:div
                  [:strong "tasks:"]
                  [filter-btn :open]
                  [filter-btn :done]
                  [filter-btn :closed]
                  [filter-btn :backlog]]]]
           (for [linked linked-entries]
             (let [ts (:timestamp linked)
                   on-drag-start (a/drag-start-fn linked put-fn)]
               ^{:key ts}
               [:tr {:on-click (up/add-search ts tab-group put-fn)}
                (let [prio (or (-> linked :task :priority) "-")]
                  [:td
                   [:span.prio {:class         prio
                                :draggable     true
                                :on-drag-start on-drag-start}
                    prio]])
                [:td.left [:strong (some-> linked
                                           :md
                                           (s/replace "#task" "")
                                           (s/replace "##" "")
                                           s/trim
                                           s/split-lines
                                           first)]]]))]]]))))

(defn briefing-view
  [entry put-fn edit-mode? local-cfg]
  (let [chart-data (subscribe [:chart-data])
        local (r/atom {:filter :open})
        stats (subscribe [:stats])
        options (subscribe [:options])
        books (reaction (:books @options))
        entries-map (subscribe [:entries-map])
        results (subscribe [:results])
        cfg (subscribe [:cfg])

        input-fn
        (fn [entry]
          (fn [ev]
            (let [day (-> ev .-nativeEvent .-target .-value)
                  updated (assoc-in entry [:briefing :day] day)]
              (put-fn [:entry/update-local updated]))))

        time-alloc-input-fn
        (fn [entry book]
          (fn [ev]
            (let [m (js/parseInt (-> ev .-nativeEvent .-target .-value))
                  s (* m 60)
                  updated (assoc-in entry [:briefing :time-allocation book] s)]
              (put-fn [:entry/update-local updated]))))]
    (fn briefing-render [entry put-fn edit-mode? local-cfg]
      (when (contains? (:tags entry) "#briefing")
        (let [books @books
              ts (:timestamp entry)
              {:keys [pomodoro-stats task-stats wordcount-stats]} @chart-data
              day (-> entry :briefing :day)
              day-stats (get pomodoro-stats day)
              dur (u/duration-string (:total-time day-stats))
              word-stats (get wordcount-stats day)
              {:keys [tasks-cnt done-cnt closed-cnt]} (get task-stats day)
              started (:started-tasks-cnt @stats)
              allocation (-> entry :briefing :time-allocation)
              actual-times (:time-by-book day-stats)
              remaining (cd/remaining-times actual-times allocation)
              past-7-days (cd/past-7-days pomodoro-stats :time-by-book)
              tab-group (:tab-group local-cfg)]
          [:div
           [:form.briefing-details
            [:fieldset
             [:legend (or day "date not set")]
             (when edit-mode?
               [:div
                [:label " Day: "]
                [:input {:type     :date
                         :on-input (input-fn entry)
                         :value    day}]])
             (when tasks-cnt
               [:div
                "Tasks: " [:strong tasks-cnt] " created, "
                [:strong done-cnt] " done, "
                [:strong closed-cnt] " closed, "
                [:strong (:started-tasks-cnt @stats)] " started. "
                [:strong (or (:word-count word-stats) 0)] " words written."])
             [:div [cc/horizontal-bar books :book-name allocation 0.0045]]
             [:div [cc/horizontal-bar books :book-name actual-times 0.0045]]
             [:div [cc/horizontal-bar books :book-name remaining 0.0045]]
             [:div
              "Total planned: "
              [:strong
               (u/duration-string
                 (apply + (map second (-> entry :briefing :time-allocation))))]
              (when (seq dur)
                [:span
                 " Logged: " [:strong dur] " in " (:total day-stats) " entries."])]
             [:div.linked-tasks
              [:table
               [:tbody
                [:tr [:th ""] [:th "book"] [:th "planned"] [:th "actual"] [:th "remaining"]]
                (for [[k v] (sort-by #(-> % second :book-name) books)]
                  (let [allocation (get-in entry [:briefing :time-allocation k] 0)
                        actual (get-in (:time-by-book day-stats) [k] 0)
                        remaining (- allocation actual)
                        color (cc/item-color (:book-name v))
                        click
                        (fn [_]
                          (when-not edit-mode?
                            (swap! local update-in [:selected] #(if (= k %) nil k))))]
                    (when (or (pos? allocation) (get actual-times k) edit-mode?)
                      ^{:key (str :time-allocation k)}
                      [:tr {:on-click click
                            :class    (when (= k (:selected @local)) "selected")}
                       [:td [:div.legend {:style {:background-color color}}]]
                       [:td [:strong (:book-name v)]]
                       [:td.time
                        (if edit-mode?
                          [:input {:on-input (time-alloc-input-fn entry k)
                                   :value    (when allocation (/ allocation 60))
                                   :type     :number}]
                          [:span (u/duration-string allocation)])]
                       [:td.time (u/duration-string actual)]
                       [:td.time [:strong (u/duration-string remaining)]]])))]]]
             [started-tasks-list tab-group put-fn]
             [open-linked-tasks-list ts local local-cfg put-fn]
             [open-entries-list tab-group :waiting-habits :habit "waiting habits" put-fn]
             (when day-stats [time-by-stories-list day-stats local])]]])))))
