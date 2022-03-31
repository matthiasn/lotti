(ns meins.electron.renderer.ui.entry.briefing.habits
  (:require [clojure.set :as set]
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.habits.util :as hu]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.utils :as eu]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(defn percent-achieved [habit]
  (let [completed (first (:completed habit))
        f (fn [[i criterion]]
            (debug criterion)
            (let [min-val (:min-val criterion)
                  req-n (:req-n criterion)
                  min-time (:min-time criterion)
                  v (get-in completed [:values i :v])
                  min-v (if min-time
                          (* 60 min-time)
                          (or min-val req-n))]
              (when (pos? min-v)
                (min (* 100 (/ v min-v)) 100))))
        criteria (hu/get-criteria (:habit_entry habit) (h/ymd (stc/now)))
        by-criteria (map f (u/idxd criteria))
        cnt (count by-criteria)]
    (when (pos? cnt)
      (/ (apply + by-criteria)
         cnt))))

(defn habit-completion [habit]
  (let [completed (first (:completed habit))
        success (:success completed)
        cls (when success "completed")
        percent-completed (percent-achieved habit)
        ts (-> habit :habit_entry :timestamp)
        started (and percent-completed (not success))]
    ^{:key ts}
    [:div.habit-monitor
     [:div.status {:class cls}
      (when started
        [:div.progress
         {:style {:width (str percent-completed "%")}}])]]))

(defn habit-line [_habit _tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        options (subscribe [:options])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))]
    (fn habit-line-render [habit tab-group]
      (let [entry (:habit_entry habit)
            story-name (:story_name (:story entry))
            ts (:timestamp entry)
            text (eu/first-line entry)
            open-new (fn [x]
                       (let [story-name (-> entry :story :story_name)
                             q (merge (up/parse-search (:timestamp x))
                                      {:story-name story-name
                                       :first-line story-name})]
                         (info q)
                         (emit [:search/add {:tab-group :left
                                             :query     q}])))
            create-entry #(let [mapping (-> @options :questionnaires :mapping)
                                mapping2 (zipmap (vals mapping) (keys mapping))
                                story (get-in entry [:story :timestamp])
                                criteria (:criteria (:habit entry))
                                q-tags (set (map (fn [x] (get mapping2 (:quest-k x))) criteria))
                                cf-tags (set (map :cf-tag criteria))
                                tags (disj (set/union cf-tags q-tags) nil)
                                completion-entry (merge {:perm_tags     tags
                                                         :primary_story story})
                                f (h/new-entry completion-entry open-new)
                                new-entry (f)]
                            (debug entry)
                            (debug new-entry))]
        [:tr {:key   ts
              :class (when (= (str ts) search-text) "selected")}
         [:td.habit-mon-col [habit-completion habit]]
         [:td.habit {:on-click create-entry} text]
         [:td.start
          [:i.fas.fa-cog
           {:on-click (up/add-search {:tab-group    tab-group
                                      :story-name   story-name
                                      :first-line   text
                                      :query-string ts} emit)}]]]))))

(defn waiting-habits
  "Renders table with open habits."
  [local]
  (let [gql-res (subscribe [:gql-res])
        habits-success (reaction (-> @gql-res :habits-success :data :habits_success))
        pvt (subscribe [:show-pvt])
        filter-fn #(swap! local update-in [:all] not)]
    (fn waiting-habits-list-render [local]
      (let [local @local
            pvt @pvt
            habits (filter #(or (:all local)
                                (not (:success (first (:completed %)))))
                           @habits-success)
            habits (filter #(or pvt (not (get-in % [:habit_entry :habit :pvt]))) habits)
            habits (filter #(-> % :habit_entry :habit :active) habits)
            tab-group :briefing]
        [:div.waiting-habits
         [:table.habits
          [:tbody
           [:tr
            [:th {:on-click filter-fn}
             [:i.fas.filter
              {:class (if (:all local)
                        "fa-angle-double-down"
                        "fa-angle-double-up")}]]
            [:th "Stuff I said I'd do."]
            [:th]
            [:th
             #_[:div.add-habit {:on-click new-habit} [:i.fas.fa-plus]]]]
           (for [habit habits]
             ^{:key (:timestamp (:habit_entry habit))}
             [habit-line habit tab-group])]]]))))
