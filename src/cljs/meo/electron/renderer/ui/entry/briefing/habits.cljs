(ns meo.electron.renderer.ui.entry.briefing.habits
  (:require [matthiasn.systems-toolbox.component :as st]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.common.utils.misc :as u]
            [meo.common.utils.parse :as up]
            [clojure.string :as s]
            [moment]
            [meo.electron.renderer.ui.entry.utils :as eu]))

(defn habit-sorter
  "Sorts tasks."
  [x y]
  (let [c (compare (get-in x [:habit :priority] :X)
                   (get-in y [:habit :priority] :X))]
    (if (not= c 0) c (compare (get-in y [:habit :points])
                              (get-in x [:habit :points])))))

(defn waiting-habits
  "Renders table with open entries, such as started tasks and open habits."
  [entry local local-cfg put-fn]
  (let [cfg (subscribe [:cfg])
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        waiting-habits (subscribe [:waiting-habits])
        options (subscribe [:options])
        expand-fn #(swap! local update-in [:expanded-habits] not)
        stories (subscribe [:stories])
        saga-filter (fn [entry]
                      (if-let [selected (:selected @local)]
                        (let [story (get @stories (:primary-story entry))]
                          (= selected (:linked-saga story)))
                        true))
        entries-map (subscribe [:entries-map])
        entries-map (reaction (merge @entries-map (:entries-map @waiting-habits)))
        habits (reaction
                 (let [find-missing (u/find-missing-entry entries-map put-fn)
                       entries (->> (:entries @waiting-habits)
                                    (map (fn [ts] (find-missing ts)))
                                    (filter saga-filter)
                                    (sort habit-sorter))
                       conf (merge @cfg @options)]
                   (if (:show-pvt @cfg)
                     entries
                     (filter (u/pvt-filter conf @entries-map) entries))))]
    (fn waiting-habits-list-render [entry local local-cfg put-fn]
      (let [habits (if (:expanded-habits @local) @habits (take 12 @habits))
            tab-group (:tab-group local-cfg)
            today (.format (moment.) "YYYY-MM-DD")
            briefing-day (-> entry :briefing :day)
            search-text @search-text]
        (when (and (= today briefing-day) (seq habits))
          [:div
           [:table.habits
            [:tbody
             [:tr {:on-click expand-fn}
              [:th [:span.fa.fa-exclamation-triangle]]
              [:th [:span.fa.fa-diamond]]
              [:th [:span.fa.fa-diamond.penalty]]
              [:th "waiting habit"]]
             (for [entry habits]
               (let [ts (:timestamp entry)
                     text (eu/first-line entry)]
                 ^{:key ts}
                 [:tr {:on-click (up/add-search ts tab-group put-fn)
                       :class    (when (= (str ts) search-text) "selected")}
                  [:td
                   (when-let [prio (-> entry :habit :priority)]
                     [:span.prio {:class prio} prio])]
                  [:td.award-points
                   (when-let [points (-> entry :habit :points)]
                     points)]
                  [:td.award-points
                   (when-let [penalty (-> entry :habit :penalty)]
                     penalty)]
                  [:td.habit text]]))]]])))))
