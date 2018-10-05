(ns meo.electron.renderer.ui.search
  (:require [meo.common.utils.parse :as p]
            [meo.electron.renderer.ui.draft :as d]
            [taoensso.timbre :refer-macros [info]]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [meo.electron.renderer.ui.entry.briefing.calendar :as ebc]
            [meo.electron.renderer.helpers :as h]))

(defn editor-state
  "Create editor-state, either from deserialized state or from search string."
  [q]
  (if-let [editor-state (:editor-state q)]
    (d/editor-state-from-raw (clj->js editor-state))
    (d/editor-state-from-text (or (:search-text q) ""))))

(defn infinite-cal-search [query put-fn]
  (let [local (r/atom {:selected {:start "2018-08-03"
                                  :end   "2018-08-13"}})
        onSelect (fn [ev]
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
                         (put-fn [:search/update q])))
                     (info @local)
                     (info "selected" selected)))]
    (fn [query put-fn]
      (let [h (- (aget js/window "innerHeight") 175)]
        [:div.infinite-cal-search
         [ebc/infinite-cal-range-adapted
          {:width           "100%"
           :height          200
           :showTodayHelper false
           :showHeader      false
           :onSelect        onSelect
           :theme           {:weekdayColor "#666"
                             :headerColor  "#888"}
           :rowHeight       36
           :selected        (:selected @local)}]]))))

(defn search-field-view
  "Renders search field for current tab."
  [_tab-group query-id _put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query (reaction (when-let [qid @query-id] (qid (:queries @query-cfg))))
        local (r/atom {:show-range-picker false

                       })]
    (fn [tab-group _query-id put-fn]
      (let [search-send (fn [text editor-state]
                          (when text
                            (let [story (first (d/entry-stories editor-state))
                                  s (merge @query
                                           (p/parse-search text)
                                           {:story        story
                                            :tab-group    tab-group
                                            :editor-state editor-state})]
                              (put-fn [:search/update s]))))
            query-deref @query
            starred (:starred query-deref)
            star-fn #(put-fn [:search/update (update-in query-deref [:starred] not)])
            flagged (:flagged query-deref)
            flag-fn #(put-fn [:search/update (update-in query-deref [:flagged] not)])
            toggle-range-picker #(swap! local update-in [:show-range-picker] not)]
        (when-not (or (:briefing query-deref)
                      (:timestamp query-deref))
          [:div.search
           [:div.search-row {:class (when (:show-range-picker @local) "cal-open")}
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
             [:i {:class    "fal fa-calendar-alt"
                  :on-click toggle-range-picker}]]]
           (when (:show-range-picker @local)
             [infinite-cal-search query put-fn])])))))
