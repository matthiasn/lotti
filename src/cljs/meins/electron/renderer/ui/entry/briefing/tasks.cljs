(ns meins.electron.renderer.ui.entry.briefing.tasks
  (:require ["moment" :as moment]
            [clojure.pprint :as pp]
            [clojure.set :as set]
            [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [moment-duration-format]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn task-sorter [x y]
  (let [c0 (compare (get-in x [:task :closed]) (get-in y [:task :closed]))
        c1 (compare (get-in x [:task :done]) (get-in y [:task :done]))
        c2 (compare (or (get-in x [:task :priority]) :X)
                    (or (get-in y [:task :priority]) :X))
        c3 (compare (:since-update x) (:since-update y))
        c4 (compare (:timestamp x) (:timestamp y))]
    (if (not= c0 0) c0 (if (not= c1 0) c1 (if (not= c2 0) c2 (if (not= c3 0) c3 c4))))))

(defn pvt-filter [show-pvt entry]
  (or (not (or (:pvt entry)
               (:pvt (:story entry))
               (-> entry :story :saga :pvt)
               (contains? (:tags entry) "#pvt")))
      @show-pvt))

(defn m-to-hhmm
  [minutes]
  (let [dur (.duration moment minutes "minutes")
        ms (.asMilliseconds dur)
        utc (.utc moment ms)
        fmt (.format utc "HH:mm")]
    fmt))

(defn s-to-hhmm [seconds]
  (let [dur (.duration moment seconds "seconds")
        ms (.asMilliseconds dur)
        utc (.utc moment ms)
        fmt (.format utc "HH:mm")]
    fmt))

(defn time-ago [ms-ago]
  (let [dur (.duration moment ms-ago)]
    (s/replace (.humanize dur false) "a few " "")))

(defn progress-svg [allocated actual]
  (let [w 50
        progress (/ actual allocated)
        stroke (if (> progress 1) "red" "green")
        x2 (min (* progress w) w)
        end-x (if (> progress 1)
                (* 50 (/ allocated actual))
                50)]
    (when (pos? allocated)
      [:svg
       {:shape-rendering "crispEdges"
        :style           {:height       "12px"
                          :width        "52px"
                          :margin-left  "5px"
                          :margin-right "5px"
                          :padding-top  "3px"}}
       [:g
        [:line {:x1           1
                :x2           w
                :y1           6
                :y2           6
                :stroke-width 6
                :stroke       "#DDD"}]
        [:line {:x1           1
                :x2           x2
                :y1           6
                :y2           6
                :stroke-width 6
                :stroke       stroke}]
        [:line {:x1           end-x
                :x2           end-x
                :y1           1
                :y2           11
                :stroke-width 2
                :stroke       "#666"}]]])))

(defn task-row [entry _cfg]
  (let [ts (:timestamp entry)
        new-entries (subscribe [:new-entries])
        busy-status (subscribe [:busy-status])]
    (fn [entry {:keys [tab-group search-text unlink show-logged? show-age show-prio
                       show-estimate show-progress show-points show-last-updated]}]
      (let [text (eu/first-line entry)
            active (= ts (:active @busy-status))
            active-selected (and (= (str ts) search-text) active)
            busy (> 1000 (- (stc/now) (:last @busy-status)))
            cls (cond
                  (and active-selected busy) "active-timer-selected-busy"
                  (and active busy) "active-timer-busy"
                  active-selected "active-timer-selected"
                  active "active-timer"
                  (= (str ts) search-text) "selected")
            estimate (get-in entry [:task :estimate_m] 0)
            logged-time (eu/logged-total @new-entries entry)
            done (get-in entry [:task :done])
            closed (get-in entry [:task :closed])
            last-updated (time-ago (:since-update entry))
            age (time-ago (- (stc/now) (:timestamp entry)))
            allocated (* 60 estimate)
            remaining (- allocated logged-time)
            story (:story entry)]
        [:tr.task {:on-click (up/add-search {:tab-group    tab-group
                                             :story-name   (-> entry :story :story_name)
                                             :first-line   text
                                             :query-string ts} emit)
                   :class    cls}
         [:td.tooltip
          [:i.fal.fa-info-circle]
          [:div.tooltiptext
           ;[:pre [:code (with-out-str (pp/pprint story))]]
           (when story
             [:div
              [:span.story {:style {:color            (:font_color story)
                                    :background-color (or (:badge_color story) "#DDD")}}
               (:story_name story)]])
           [:h4 text]
           (when-let [prio (some-> entry :task :priority (name))]
             [:div [:label "Task priority: "] [:strong prio]])
           [:div [:label "Task idle for: "] [:strong age]]
           [:div [:label "Time allocated: "] [:strong (h/s-to-hh-mm-ss allocated)]]
           [:div [:label "Time logged: "] [:strong (h/s-to-hh-mm-ss logged-time)]]
           (when (pos? allocated)
             [:div [:label "Time remaining: "] [:strong (h/s-to-hh-mm-ss remaining)]])]]
         (when show-prio
           [:td
            (if (or done closed)
              [:span.checked
               (when done [:i.fas.fa-check])
               (when closed [:i.fas.fa-times])]
              (when-let [prio (some-> entry :task :priority (name))]
                [:span.prio {:class prio} prio]))])
         (when show-points
           [:td.award-points
            (when-let [points (-> entry :task :points)]
              points)])
         (when show-estimate
           [:td.estimate
            (let [seconds (* 60 estimate)]
              [:span {:class cls}
               (s-to-hhmm (.abs js/Math seconds))])])
         (when show-last-updated
           [:td.time last-updated])
         (when show-age
           [:td.time age])
         (when show-logged?
           [:td.estimate.time
            (let [seconds (* 60 estimate)
                  remaining (- seconds logged-time)
                  cls (when (neg? remaining) "neg")]
              [:span {:class cls}
               (h/s-to-hh-mm-ss logged-time)])])
         (when show-progress
           [:td.progress [progress-svg allocated logged-time]])
         [:td.text text]
         [:td.last (when unlink
                     [:i.fa.far.fa-unlink {:on-click #(unlink ts)}])]]))))

(defn open-task-row [entry _cfg]
  (let [ts (:timestamp entry)]
    (fn [entry {:keys [tab-group search-text unlink show-points]}]
      (let [text (str (eu/first-line entry))
            cls (when (= (str ts) search-text) "selected")
            age (time-ago (- (stc/now) (:timestamp entry)))]
        [:tr.task {:on-click (up/add-search {:tab-group    tab-group
                                             :story-name   (-> entry :story :story_name)
                                             :query-string ts
                                             :first-line   text}
                                            emit)
                   :class    cls}
         [:td (when-let [prio (some-> entry :task :priority (name))]
                [:span.prio {:class prio} prio])]
         (when show-points
           [:td.award-points
            (when-let [points (-> entry :task :points)]
              points)])
         [:td.time age]
         [:td.text
          (subs text 0 50)]
         (when unlink
           [:td [:i.fa.far.fa-unlink {:on-click unlink}]])]))))

(defn add-last-updated [x]
  (let [last-saved-all (into [(:last_saved x)]
                             (map :last_saved (:comments x)))
        last-updated (apply max last-saved-all)]
    (assoc-in x [:since-update] (- last-updated (stc/now)))))

(defn started-tasks
  "Renders table with open entries, such as started tasks and open habits."
  [local cfg]
  (let [gql-res (subscribe [:gql-res])
        show-pvt (subscribe [:show-pvt])
        started-tasks (reaction (->> @gql-res
                                     :started-tasks
                                     :data
                                     :started_tasks
                                     (map add-last-updated)))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        on-hold-filter (fn [entry]
                         (let [on-hold (:on_hold (:task entry))]
                           (if (:on-hold cfg)
                             on-hold
                             (not on-hold))))
        saga-filter (fn [entry]
                      (if (seq (:selected-set @local))
                        (let [saga (get-in entry [:story :saga :timestamp])]
                          (contains? (:selected-set @local) saga))
                        true))
        open-filter (fn [entry] (not (-> entry :task :done)))
        entries-list (reaction (->> @started-tasks
                                    (filter on-hold-filter)
                                    (filter saga-filter)
                                    (filter open-filter)
                                    (filter (partial pvt-filter show-pvt))
                                    (sort task-sorter)))]
    (fn started-tasks-list-render [local cfg]
      (let [entries-list @entries-list
            search-text @search-text
            show-points (:show-points @local)]
        (when (seq entries-list)
          [:div.started-tasks
           [:table.tasks
            [:tbody
             [:tr
              [:th.xs]
              (when show-points
                [:th {:on-click #(swap! local assoc :show-points false)}
                 [:i.fa.far.fa-gem]])
              [:th "progress"]
              [:th
               [:div
                (if (:on-hold cfg)
                  "on hold"
                  "started tasks")]]]
             (for [entry entries-list]
               ^{:key (:timestamp entry)}
               [task-row entry {:tab-group         :briefing
                                :search-text       search-text
                                :show-points       false
                                :show-last-updated false
                                :show-progress     true
                                :show-logged?      false}])]]])))))

(defn open-task-sorter [x y]
  (let [c0 (compare (or (get-in x [:task :priority]) :X)
                    (or (get-in y [:task :priority]) :X))
        c1 (compare (:timestamp y) (:timestamp x))]
    (if (not= c0 0) c0 c1)))

(defn open-tasks
  "Renders table with open tasks."
  [local _local-cfg]
  (let [gql-res (subscribe [:gql-res])
        show-pvt (subscribe [:show-pvt])
        open-tasks (reaction (-> @gql-res :open-tasks :data :open_tasks))
        started-tasks (reaction (->> @gql-res
                                     :started-tasks
                                     :data
                                     :started_tasks
                                     (map :timestamp)
                                     set))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        on-hold-filter (fn [entry]
                         (let [on-hold (:on_hold (:task entry))]
                           (if (:on-hold @local)
                             on-hold
                             (not on-hold))))
        saga-filter (fn [entry]
                      (if (seq (:selected-set @local))
                        (let [saga (get-in entry [:story :saga :timestamp])]
                          (contains? (:selected-set @local) saga))
                        true))
        open-filter (fn [entry] (not (-> entry :task :done)))
        closed-filter (fn [entry] (not (-> entry :task :closed)))
        entries-list (reaction (->> @open-tasks
                                    (filter on-hold-filter)
                                    (filter saga-filter)
                                    (filter open-filter)
                                    (filter (partial pvt-filter show-pvt))
                                    (filter closed-filter)))
        on-change #(swap! local assoc-in [:task-search] (h/target-val %))]
    (fn open-tasks-render [local local-cfg]
      (let [tab-group (:tab-group local-cfg)
            entries-list (filter #(not (contains? @started-tasks (:timestamp %))) @entries-list)
            task-search (:task-search @local "")
            task-search-filter (fn [entry] (h/str-contains-lc? (:md entry) task-search))
            entries-list (filter task-search-filter entries-list)
            show-points (:show-points @local)]
        [:div.open-tasks
         [:table.tasks
          [:tbody
           [:tr
            [:th.xs [:i.far.fa-exclamation-triangle]]
            (when show-points
              [:th [:i.fa.far.fa-gem]])
            [:th "age"]
            [:th "open tasks"
             [:i.fas.fa-search]
             [:input {:on-input on-change
                      :value    (:task-search @local)}]]]
           (doall
             (for [entry (sort open-task-sorter entries-list)]
               ^{:key (:timestamp entry)}
               [open-task-row entry {:tab-group    tab-group
                                     :search-text  @search-text
                                     :show-points  show-points
                                     :show-logged? true}]))]]]))))

(defn open-linked-tasks
  "Show open tasks that are also linked with the briefing entry."
  [local _local-cfg]
  (let [gql-res (subscribe [:gql-res])
        show-pvt (subscribe [:show-pvt])
        started-tasks (reaction (-> @gql-res :started-tasks :data :started_tasks))
        briefing (reaction (-> @gql-res :briefing :data :briefing))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        by-ts (reaction (get-in @gql-res [:logged-by-day :data :logged_time :by_ts]))
        activity (reaction (->> @by-ts (map :parent) (filter identity) set))
        linked-filters {:all      identity
                        :open     #(and (not (-> % :task :done))
                                        (not (-> % :task :closed)))
                        :done     #(-> % :task :done)
                        :closed   #(-> % :task :closed)
                        :activity identity}
        filter-btn (fn [fk text]
                     [:span.filter {:class    (when (= fk (:filter @local)) "current")
                                    :on-click #(swap! local assoc-in [:filter] fk)}
                      (name fk) (when (= fk (:filter @local)) text)])]
    (fn open-linked-tasks-render [local local-cfg]
      (let [{:keys [tab-group]} local-cfg
            linked-entries (:linked @briefing)
            current-filter (get linked-filters (:filter @local))
            saga-filter (fn [entry]
                          (if (seq (:selected-set @local))
                            (let [saga (get-in entry [:story :saga :timestamp])]
                              (contains? (:selected-set @local) saga))
                            true))
            started-tasks (set (map :timestamp @started-tasks))
            task-filter #(contains? (set/union (:perm_tags %) (:tags %)) "#task")
            linked-tasks (->> linked-entries
                              (filter task-filter)
                              (filter current-filter)
                              (filter saga-filter)
                              (filter (partial pvt-filter show-pvt))
                              (filter #(not (contains? started-tasks (:timestamp %)))))
            filter-k (:filter @local)
            linked-tasks (if (= filter-k :activity)
                           @activity
                           linked-tasks)
            unlink (when-not (= filter-k :activity)
                     (fn [ts]
                       (let [timestamps [ts (:timestamp @briefing)]]
                         (emit [:entry/unlink timestamps]))))
            search-text @search-text
            show-points (:show-points @local)]
        [:div.linked-tasks
         [filter-btn :all]
         [filter-btn :open]
         [filter-btn :done]
         [filter-btn :closed]
         [filter-btn :activity]
         [:table.tasks
          [:tbody
           [:tr
            [:th.xs]
            (when show-points
              [:th [:i.fa.far.fa-gem]])
            [:th.xs]
            [:th [:i.fa.far.fa-clock]]
            [:th "pinned tasks"]
            [:th.xs [:i.fa.far.fa-link]]]
           (for [entry (sort task-sorter linked-tasks)]
             ^{:key (:timestamp entry)}
             [task-row entry {:tab-group     tab-group
                              :search-text   search-text
                              :show-points   show-points
                              :show-estimate true
                              :show-age      false
                              :show-progress false
                              :show-prio     true
                              :unlink        unlink}])]]]))))
