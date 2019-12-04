(ns meins.electron.renderer.ui.entry.briefing.time
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.charts.common :as cc]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer [reaction]]))

(defn time-by-stories
  "Render list of times spent on individual stories, plus the total."
  [day-stats local put-fn]
  (let [stories (subscribe [:stories])
        saga-filter (fn [[k v]]
                      (if-let [selected (:selected @local)]
                        (let [story (get @stories k)]
                          (= selected (:linked-saga story)))
                        true))
        story-name-mapper (fn [[k v]]
                            (let [s (or (:story_name (get @stories k)) "none")]
                              [k s v]))]
    (fn [day-stats local put-fn]
      (let [date (:date_string day-stats)
            time-by-story (->> day-stats
                               :time-by-story
                               (filter saga-filter)
                               (map story-name-mapper)
                               (sort-by second))]
        (when date
          [:table
           [:tbody
            [:tr [:th ""] [:th "story"] [:th "actual"]]
            (for [[id story v] time-by-story]
              (let [color (cc/item-color story)
                    q (merge
                        (up/parse-search date)
                        {:story (when-not (js/isNaN id) id)})
                    click-fn (fn [_]
                               (put-fn [:search/add {:tab-group :left
                                                     :query     q}]))]
                ^{:key story}
                [:tr {:on-click click-fn}
                 [:td [:div.legend {:style {:background-color color}}]]
                 [:td [:strong story]]
                 [:td.time (u/duration-string v)]]))]])))))

(defn time-by-sagas [entry day-stats local edit-mode? put-fn]
  (let [sagas (subscribe [:sagas])
        time-alloc (fn [entry saga]
                     (fn [ev]
                       (let [v (.. ev -target -value)
                             s (when (seq v)
                                 (* 60 (.asMinutes (.duration moment v))))
                             path [:briefing :time-allocation saga]
                             updated (assoc-in entry path s)]
                         (when s
                           (put-fn [:entry/update-local updated])))))
        filter-click #(swap! local update-in [:outstanding-time-filter] not)]
    (fn [entry day-stats local edit-mode? put-fn]
      (let [actual-times (:time-by-saga day-stats)
            local-snapshot @local
            filtered? (:outstanding-time-filter local-snapshot)
            filter-cls (when-not filtered? "inactive")
            sagas (sort-by #(-> % second :saga-name) @sagas)
            selected (:selected local-snapshot)]
        [:table
         [:tbody
          [:tr
           [:th [:span.fa.fa-filter
                 {:on-click filter-click
                  :class    filter-cls}]]
           [:th "saga"]
           [:th "planned"]
           [:th "actual"]
           [:th "remaining"]]
          (for [[k v] sagas]
            (let [allocation (get-in entry [:briefing :time-allocation k] 0)
                  actual (get-in actual-times [k] 0)
                  remaining (- allocation actual)
                  color (cc/item-color (:saga-name v))
                  click
                  (fn [_]
                    (when-not edit-mode?
                      (swap! local update-in [:selected] #(if (= k %) nil k))))]
              (when (or (pos? allocation) (get actual-times k) edit-mode?)
                (when (and (or (not filtered?) (pos? remaining) edit-mode?)
                           (or (not selected) (= selected k)))
                  ^{:key (str :time-allocation k)}
                  [:tr {:on-click click
                        :class    (when (= k (:selected local-snapshot)) "selected")}
                   [:td [:div.legend {:style {:background-color color}}]]
                   [:td [:strong (:saga-name v)]]
                   [:td.time
                    (if edit-mode?
                      [:input {:on-change (time-alloc entry k)
                               :value     (when allocation
                                            (h/s-to-hh-mm allocation))
                               :type      :time}]
                      [:span (u/duration-string allocation)])]
                   [:td.time (u/duration-string actual)]
                   [:td.time [:strong (u/duration-string remaining)]]]))))]]))))
