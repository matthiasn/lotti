(ns meo.electron.renderer.ui.entry.briefing.tasks
  (:require [matthiasn.systems-toolbox.component :as st]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [meo.common.utils.parse :as up]
            [clojure.string :as s]
            [moment]
            [clojure.set :as set]))

(defn task-sorter
  "Sorts tasks."
  [x y]
  (let [c (compare (get-in x [:task :priority] :X)
                   (get-in y [:task :priority] :X))]
    (if (not= c 0) c (compare (:timestamp x)
                              (:timestamp y)))))

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
        new-entries (subscribe [:new-entries])
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
            estimate (get-in entry [:task :estimate_m] 0)
            logged-time (eu/logged-total new-entries entry)]
        [:tr.task {:on-click (up/add-search ts tab-group put-fn)
                   :class    cls}
         [:td
          (if (get-in entry [:task :done])
            [:span.checked
             [:i.fas.fa-check]]
            (when-let [prio (some-> entry :task :priority (name))]
              [:span.prio {:class prio} prio]))]
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
                           logged-time
                           (:completed_s (:task entry)))
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
  (let [gql-res (subscribe [:gql-res])
        started-tasks (reaction (-> @gql-res :started-tasks :data :started_tasks))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        on-hold-filter (fn [entry]
                         (let [on-hold (:on_hold (:task entry))]
                           (if (:on-hold @local)
                             on-hold
                             (not on-hold))))
        saga-filter (fn [entry]
                      (if-let [selected (:selected @local)]
                        (let [saga (get-in entry [:story :saga :timestamp])]
                          (= selected saga))
                        true))
        open-filter (fn [entry] (not (-> entry :task :done)))
        filter-btn (fn [fk]
                     [:span.filter {:class    (when (:on-hold @local) "current")
                                    :on-click #(swap! local update-in [:on_hold] not)}
                      (name fk)])
        entries-list (reaction (->> @started-tasks
                                    (filter on-hold-filter)
                                    (filter saga-filter)
                                    (filter open-filter)
                                    (sort task-sorter)))]
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
                [filter-btn :on_hold]]]]
             (for [entry entries-list]
               ^{:key (:timestamp entry)}
               [task-line entry put-fn {:tab-group    tab-group
                                        :search-text  search-text
                                        :show-logged? true}])]]])))))

(defn open-linked-tasks
  "Show open tasks that are also linked with the briefing entry."
  [ts local put-fn]
  (let [gql-res (subscribe [:gql-res])
        started-tasks (reaction (-> @gql-res :started-tasks :data :started_tasks))
        briefing (reaction (-> @gql-res :briefing :data :briefing))
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
            current-filter (get linked-filters (:filter @local))
            saga-filter (fn [entry]
                          (if-let [selected (:selected @local)]
                            (let [story (:story entry)]
                              (= selected (:timestamp (:saga story))))
                            true))
            started-tasks (set (map :timestamp @started-tasks))
            task-filter #(contains? (set/union (:perm_tags %) (:tags %)) "#task")
            linked-tasks (->> linked-entries
                              (filter task-filter)
                              (filter current-filter)
                              (filter saga-filter)
                              (filter #(not (contains? started-tasks (:timestamp %))))
                              (sort-by #(or (-> % :task :priority) :X)))
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
