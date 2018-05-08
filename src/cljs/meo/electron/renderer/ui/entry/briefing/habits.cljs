(ns meo.electron.renderer.ui.entry.briefing.habits
  (:require [matthiasn.systems-toolbox.component :as st]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.common.utils.misc :as u]
            [meo.common.utils.parse :as up]
            [clojure.string :as s]
            [moment]
            [taoensso.timbre :refer-macros [info]]
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
  [local local-cfg put-fn]
  (let [cfg (subscribe [:cfg])
        gql-res (subscribe [:gql-res])
        briefing (reaction (-> @gql-res :briefing :data :briefing))
        habits (reaction (-> @gql-res :briefing :data :waiting-habits))
        query-cfg (subscribe [:query-cfg])
        query-id-left (reaction (get-in @query-cfg [:tab-groups :left :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id-left :search-text]))
        options (subscribe [:options])
        expand-fn #(swap! local update-in [:expanded-habits] not)
        saga-filter (fn [entry]
                      (if-let [selected (:selected @local)]
                        (let [saga (-> entry :story :linked-saga :timestamp)]
                          (= selected saga))
                        true))
        habits (reaction (->> @habits
                              (filter saga-filter)
                              (sort habit-sorter)))]
    (fn waiting-habits-list-render [local local-cfg put-fn]
      (let [habits @habits
            habits (if (:show-pvt @cfg)
                     habits
                     (filter (u/pvt-filter2 (merge @cfg @options)) habits))
            habits (if (:expanded-habits @local) habits (take 12 habits))
            tab-group (:tab-group local-cfg)
            today (.format (moment.) "YYYY-MM-DD")
            search-text @search-text]
        (when (and (= today (:day @briefing)) (seq habits))
          [:div
           [:table.habits
            [:tbody
             [:tr {:on-click expand-fn}
              [:th.xs [:span.fa.fa-exclamation-triangle]]
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
                   (when-let [prio (some-> entry :habit :priority (subs 1))]
                     [:span.prio {:class prio} prio])]
                  [:td.award-points
                   (when-let [points (-> entry :habit :points)]
                     points)]
                  [:td.award-points
                   (when-let [penalty (-> entry :habit :penalty)]
                     penalty)]
                  [:td.habit text]]))]]])))))
