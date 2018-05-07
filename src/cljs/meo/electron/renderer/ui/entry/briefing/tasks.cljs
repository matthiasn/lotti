(ns meo.electron.renderer.ui.entry.briefing.tasks
  (:require [matthiasn.systems-toolbox.component :as st]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.common.utils.misc :as u]
            [taoensso.timbre :as timbre :refer-macros [info debug]]
            [meo.electron.renderer.ui.entry.actions :as a]
            [meo.common.utils.parse :as up]
            [clojure.string :as s]
            [moment]
            [meo.electron.renderer.ui.entry.utils :as eu]))

(defn task-sorter
  "Sorts tasks."
  [x y]
  (let [c (compare (get-in x [:task :priority] :X)
                   (get-in y [:task :priority] :X))]
    (if (not= c 0) c (compare (get-in x [:task :active-from])
                              (get-in y [:task :active-from])))))

(defn m-to-hhmm
  [minutes]
  (let [dur (.duration moment minutes "minutes")
        ms (.asMilliseconds dur)
        utc (.utc moment ms)
        fmt (.format utc "HH:mm")]
    fmt))

(defn s-to-hhmmss [seconds]
  (let [dur (.duration moment seconds "seconds")
        ms (.asMilliseconds dur)
        utc (.utc moment ms)
        fmt (.format utc "HH:mm:ss")]
    fmt))

(defn s-to-hhmm [seconds]
  (let [dur (.duration moment seconds "seconds")
        ms (.asMilliseconds dur)
        utc (.utc moment ms)
        fmt (.format utc "HH:mm")]
    fmt))

(defn task-line [entry _put-fn _cfg]
  (let [ts (:timestamp entry)
        logged-time (subscribe [:entry-logged-time ts])
        busy-status (subscribe [:busy-status])]
    (fn [entry put-fn {:keys [tab-group search-text unlink show-logged?]}]
      (let [text (eu/first-line entry)
            active (= ts (:active @busy-status))
            active-selected (and (= (str ts) search-text) active)
            busy (> 1000 (- (st/now) (:last @busy-status)))
            cls (cond
                  (and active-selected busy) "active-timer-selected-busy"
                  (and active busy) "active-timer-busy"
                  active-selected "active-timer-selected"
                  active "active-timer"
                  (= (str ts) search-text) "selected")
            estimate (get-in entry [:task :estimate-m] 0)]
        [:tr.task {:on-click (up/add-search ts tab-group put-fn)
                   :class    cls}
         [:td
          (when-let [prio (-> entry :task :priority)]
            [:span.prio {:class (name prio)} prio])]
         [:td.award-points
          (when-let [points (-> entry :task :points)]
            points)]
         [:td.estimate
          (let [seconds (* 60 estimate)]
            [:span {:class cls}
             (s-to-hhmm (.abs js/Math seconds))])]
         (when show-logged?
           [:td.estimate
            (let [actual @logged-time
                  seconds (* 60 estimate)
                  remaining (- seconds actual)
                  cls (when (neg? remaining) "neg")]
              [:span {:class cls}
               (s-to-hhmmss actual)])])
         [:td.text text]
         (when unlink
           [:td [:i.fa.far.fa-unlink {:on-click unlink}]])]))))

(defn task-line2 [entry _put-fn _cfg]
  (let [ts (:timestamp entry)
        busy-status (subscribe [:busy-status])]
    (fn [entry put-fn {:keys [tab-group search-text unlink show-logged?]}]
      (let [text (eu/first-line entry)
            active (= ts (:active @busy-status))
            active-selected (and (= (str ts) search-text) active)
            busy (> 1000 (- (st/now) (:last @busy-status)))

            cls (cond
                  (and active-selected busy) "active-timer-selected-busy"
                  (and active busy) "active-timer-busy"
                  active-selected "active-timer-selected"
                  active "active-timer"
                  (= (str ts) search-text) "selected")
            estimate (get-in entry [:task :estimate-m] 0)]
        [:tr.task {:on-click (up/add-search ts tab-group put-fn)
                   :class    cls}
         [:td
          (when-let [prio (-> entry :task :priority)]
            [:span.prio {:class (subs prio 1)} (subs prio 1)])]
         [:td.award-points
          (when-let [points (-> entry :task :points)]
            points)]
         [:td.estimate
          (let [seconds (* 60 estimate)]
            [:span {:class cls}
             (s-to-hhmm (.abs js/Math seconds))])]
         (when show-logged?
           [:td.estimate
            (let [actual (:completed-s (:task entry))
                  seconds (* 60 estimate)
                  remaining (- seconds actual)
                  cls (when (neg? remaining) "neg")]
              [:span {:class cls}
               (s-to-hhmmss actual)])])
         [:td.text text]
         (when unlink
           [:td [:i.fa.far.fa-unlink {:on-click unlink}]])]))))

(defn started-tasks
  "Renders table with open entries, such as started tasks and open habits."
  [local local-cfg put-fn]
  (let [cfg (subscribe [:cfg])
        gql-res (subscribe [:gql-res])
        started-tasks (reaction (:started-tasks (:started-tasks @gql-res)))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        options (subscribe [:options])
        on-hold-filter (fn [entry]
                         (let [on-hold (:on-hold (:task entry))]
                           (if (:on-hold @local)
                             on-hold
                             (not on-hold))))
        saga-filter (fn [entry]
                      (if-let [selected (:selected @local)]
                        (let [saga (get-in entry [:story :linked-saga :timestamp])]
                          (= selected saga))
                        true))
        open-filter (fn [entry] (not (-> entry :task :done)))
        filter-btn (fn [fk]
                     [:span.filter {:class    (when (:on-hold @local) "current")
                                    :on-click #(swap! local update-in [:on-hold] not)}
                      (name fk)])
        entries-list (reaction
                        (let [entries (->> @started-tasks
                                           (filter on-hold-filter)
                                           (filter saga-filter)
                                           (filter open-filter)
                                           (sort task-sorter))
                              conf (merge @cfg @options)]
                          (if (:show-pvt @cfg)
                            entries
                            (filter (u/pvt-filter2 conf) entries))))]
    (fn started-tasks-list-render [local local-cfg put-fn]
      (info @local)
      (let [entries-list @entries-list
            tab-group (:tab-group local-cfg)
            search-text @search-text]
        (when (seq entries-list)
          [:div.linked-tasks
           [:table.tasks
            [:tbody
             [:tr
              [:th.xs [:i.far.fa-exclamation-triangle]]
              [:th [:i.fa.far.fa-gem]]
              [:th [:i.fal.fa-bell]]
              [:th [:i.far.fa-stopwatch]]
              [:th
               [:div
                "started tasks: "
                [filter-btn :on-hold]]]]
             (for [entry entries-list]
               ^{:key (:timestamp entry)}
               [task-line2 entry put-fn {:tab-group    tab-group
                                         :search-text  search-text
                                         :show-logged? true}])]]])))))

(defn open-linked-tasks
  "Show open tasks that are also linked with the briefing entry."
  [ts local put-fn]
  (let [entry (:entry (eu/entry-reaction ts))
        cfg (subscribe [:cfg])
        options (subscribe [:options])
        stories (subscribe [:stories])
        gql-res (subscribe [:gql-res])
        started-tasks (reaction (:started-tasks (:started-tasks @gql-res)))
        entries-map (subscribe [:entries-map])
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        linked-filters {:active  (up/parse-search "#task ~#done ~#closed ~#backlog")
                        :open    (up/parse-search "#task ~#done ~#closed ~#backlog")
                        :done    (up/parse-search "#task #done")
                        :closed  (up/parse-search "#task #closed")
                        :backlog (up/parse-search "#task #backlog")}
        filter-btn (fn [fk text]
                     [:span.filter {:class    (when (= fk (:filter @local)) "current")
                                    :on-click #(swap! local assoc-in [:filter] fk)}
                      (name fk) (when (= fk (:filter @local)) text)])
        entries-w-done (reaction
                         (into {} (map (fn [[k v]]
                                         [k (if (-> v :task :done)
                                              (update-in v [:tags] conj "#done")
                                              v)])
                                       @entries-map)))
        linked-mapper (u/find-missing-entry entries-map put-fn)]
    (fn open-linked-tasks-render [ts local local-cfg put-fn]
      (let [{:keys [tab-group]} local-cfg
            linked-entries-set (into (sorted-set) (:linked-entries-list @entry))
            linked-entries (mapv linked-mapper linked-entries-set)
            conf (merge @cfg @options)
            add-search (up/add-search (str "l:" ts) :off put-fn)
            linked-entries (if (:show-pvt conf)
                             linked-entries
                             (filter (u/pvt-filter conf entries-w-done) linked-entries))
            current-filter (get linked-filters (:filter @local))
            filter-fn (u/linked-filter-fn entries-w-done current-filter put-fn)
            saga-filter (fn [entry]
                          (if-let [selected (:selected @local)]
                            (let [story (get @stories (:primary-story entry))]
                              (debug :saga-filter selected story)
                              (= selected (:timestamp (:linked-saga story))))
                            true))
            active-filter (fn [t]
                            (let [active-from (-> t :task :active-from)]
                              (if (and active-from (= (:filter @local) :active))
                                (let [from-now (.fromNow (moment active-from))]
                                  (s/includes? from-now "ago"))
                                true)))
            started-tasks (set (map :timestamp @started-tasks))
            linked-tasks (->> linked-entries
                              (filter filter-fn)
                              (filter saga-filter)
                              (filter #(not (contains? started-tasks (:timestamp %))))
                              (filter active-filter)
                              (sort-by #(or (-> % :task :priority) :X)))
            time-reducer (fn [acc t] (+ acc (get-in t [:task :estimate-m] 0)))
            total-time (reduce time-reducer 0 linked-tasks)
            unlink (fn [entry ts]
                     (let [rm-link #(disj (set %) ts)
                           upd (update-in entry [:linked-entries] rm-link)]
                       (put-fn [:entry/update upd])))
            search-text @search-text]
        (add-search)
        (when (seq linked-tasks)
          [:div.linked-tasks
           [filter-btn :active (str " - " (m-to-hhmm total-time))]
           [filter-btn :open (str " - " (m-to-hhmm total-time))]
           [filter-btn :done]
           [filter-btn :closed]
           [filter-btn :backlog]
           [:table.tasks
            [:tbody
             [:tr
              [:th.xs [:i.far.fa-exclamation-triangle]]
              [:th [:i.fa.far.fa-gem]]
              [:th [:i.fa.far.fa-stopwatch]]
              [:th [:strong "tasks"]]
              [:th.xs [:i.fa.far.fa-link]]]
             (for [entry linked-tasks]
               ^{:key (:timestamp entry)}
               [task-line entry put-fn {:tab-group   tab-group
                                        :search-text search-text
                                        :unlink      unlink}])]]])))))
