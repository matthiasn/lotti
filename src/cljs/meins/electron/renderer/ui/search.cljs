(ns meins.electron.renderer.ui.search
  (:require [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.parse :as p]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.draft :as d]
            [meins.electron.renderer.ui.entry.briefing.calendar :as ebc]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [info]]))

(defn editor-state
  "Create editor-state, either from deserialized state or from search string."
  [q]
  (if-let [editor-state (:editor-state q)]
    (d/editor-state-from-raw (clj->js editor-state))
    (d/editor-state-from-text (or (:search-text q) ""))))

(defn infinite-cal-search [query local]
  (let [onSelect (fn [ev]
                   (let [selected (js->clj ev :keywordize-keys true)
                         start (h/ymd (:start selected))
                         end (h/ymd (:end selected))
                         sel {:start start
                              :end   end}]
                     (swap! local assoc-in [:selected] sel)
                     (when (= (:eventType selected) 3)
                       (let [q (merge @query
                                      {:from start
                                       :to   end})]
                         ;(swap! local assoc-in [:show-range-picker] false)
                         (emit [:search/update q])))))]
    (fn [_query local]
      (let [selected (:selected @local)
            from (:start selected)
            to (:end selected)]
        [:div.infinite-cal-search
         (if (:show-range-picker @local)
           [ebc/infinite-cal-range-adapted
            {:width     "100%"
             :height    200
             :onSelect  onSelect
             :theme     {:weekdayColor "#666"
                         :headerColor  "#778"}
             :rowHeight 40
             :selected  (:selected @local)}]
           (when (and from to (not= from to))
             [:div.from-to
              [:span.label "Start:"]
              [:span.from from]
              [:span.label "End:"]
              [:span.to to]]
             [:div.header-only
              [ebc/infinite-cal-range-adapted
               {:width          "100%"
                :height         0
                :onSelect       onSelect
                :theme          {:weekdayColor "#666"
                                 :headerColor  "#778"}
                :displayOptions {:showWeekdays    false
                                 :showTodayHelper false}
                :selected       (:selected @local)}]]))]))))

(defn search-field-view
  "Renders search field for current tab."
  [_tab-group query-id]
  (let [query-cfg (subscribe [:query-cfg])
        query (reaction (when-let [qid @query-id] (qid (:queries @query-cfg))))
        local (r/atom {:show-range-picker false
                       :selected          {:start (h/ymd (st/now))
                                           :end   (h/ymd (st/now))}})]
    (fn [tab-group _query-id]
      (let [search-send (fn [text editor-state]
                          (when text
                            (let [story (first (d/entry-stories editor-state))
                                  s (merge @query
                                           (p/parse-search text)
                                           {:story        story
                                            :tab-group    tab-group
                                            :editor-state editor-state
                                            :to           (:to @query)
                                            :from         (:from @query)})]
                              (emit [:search/update s]))))
            query-deref @query
            starred (:starred query-deref)
            star-fn #(emit [:search/update (update-in query-deref [:starred] not)])
            flagged (:flagged query-deref)
            flag-fn #(emit [:search/update (update-in query-deref [:flagged] not)])
            toggle-range-picker #(swap! local update-in [:show-range-picker] not)
            from (:from query-deref)
            to (:to query-deref)
            range-set? (or (and from to)
                           (and (:start (:selected @local))
                                (:end (:selected @local))))]
        (when (and from to) (swap! local assoc-in [:selected] {:start from :end to}))
        (when-not (or (:briefing query-deref)
                      (:timestamp query-deref))
          [:div.search
           [:div.search-row {:class (when (:show-range-picker @local)
                                      "cal-open")}
            [:div [:i.far.fa-search]]
            [d/draft-search-field (editor-state query-deref) search-send]
            [:div.star
             [:i {:class    (if starred
                              "fas fa-star starred"
                              "fal fa-star")
                  :on-click star-fn}]]
            [:div.flag
             [:i {:class    (if flagged
                              "fas fa-flag flagged"
                              "fal fa-flag")
                  :on-click flag-fn}]]
            [:div.cal
             [:i.fa-calendar-alt {:class    (if range-set? "fas" "fal")
                                  :on-click toggle-range-picker}]]]
           [infinite-cal-search query local]])))))
