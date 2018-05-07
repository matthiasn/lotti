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
          (when-let [prio (some-> entry :task :priority (subs 1))]
            [:span.prio {:class prio} prio])]
         [:td.award-points
          (when-let [points (-> entry :task :points)]
            points)]
         [:td.estimate
          (let [seconds (* 60 estimate)]
            [:span {:class cls}
             (s-to-hhmm (.abs js/Math seconds))])]
         (when show-logged?
           [:td.estimate
            (let [actual (if (and active busy)
                           @logged-time
                           (:completed-s (:task entry)))
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
        started-tasks (reaction (:started-tasks (:briefing @gql-res)))
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
               [task-line entry put-fn {:tab-group    tab-group
                                        :search-text  search-text
                                        :show-logged? true}])]]])))))

(defn open-linked-tasks
  "Show open tasks that are also linked with the briefing entry."
  [ts local put-fn]
  (let [cfg (subscribe [:cfg])
        options (subscribe [:options])
        gql-res (subscribe [:gql-res])
        started-tasks (reaction (:started-tasks (:briefing @gql-res)))
        briefing (reaction (:briefing (:briefing @gql-res)))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        linked-filters {:all  identity
                        :open #(not (-> % :task :done))
                        :done #(-> % :task :done)}
        filter-btn (fn [fk text]
                     [:span.filter {:class    (when (= fk (:filter @local)) "current")
                                    :on-click #(swap! local assoc-in [:filter] fk)}
                      (name fk) (when (= fk (:filter @local)) text)])]
    (fn open-linked-tasks-render [ts local local-cfg put-fn]
      (let [{:keys [tab-group]} local-cfg
            linked-entries (:linked @briefing)
            conf (merge @cfg @options)
            linked-entries (if (:show-pvt conf)
                             linked-entries
                             (filter (u/pvt-filter2 conf) linked-entries))
            current-filter (get linked-filters (:filter @local))
            saga-filter (fn [entry]
                          (if-let [selected (:selected @local)]
                            (let [story (:story entry)]
                              (= selected (:timestamp (:linked-saga story))))
                            true))
            started-tasks (set (map :timestamp @started-tasks))
            linked-tasks (->> linked-entries
                              (filter current-filter)
                              (filter saga-filter)
                              (filter #(not (contains? started-tasks (:timestamp %))))
                              (sort-by #(or (-> % :task :priority) ":X")))
            unlink (fn [entry ts]
                     (let [rm-link #(disj (set %) ts)
                           upd (update-in entry [:linked-entries] rm-link)]
                       (put-fn [:entry/update upd])))
            search-text @search-text]
        (when (seq linked-entries)
          [:div.linked-tasks
           [filter-btn :open]
           [filter-btn :done]
           [filter-btn :all]
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
