(ns meo.electron.renderer.ui.search
  (:require [meo.electron.renderer.helpers :as h]
            [meo.common.utils.misc :as u]
            [meo.common.utils.parse :as p]
            [meo.electron.renderer.ui.draft :as d]
            [reagent.ratom :refer-macros [reaction]]
            [clojure.string :as s]
            [clojure.set :as set]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]))

(defn tags-view
  "Renders a row with tags, if any in current query."
  [current-query]
  (let [get-tags #(% current-query)
        tags (get-tags :tags)
        not-tags (get-tags :not-tags)
        mentions (get-tags :mentions)]
    (when (or (seq tags) (seq not-tags) (seq mentions))
      [:div.hashtags
       (for [tag tags]
         ^{:key (str "search-" tag)}
         [:span.hashtag tag])
       (for [tag not-tags]
         ^{:key (str "search-n" tag)}
         [:span.hashtag.not-tag tag])
       (for [tag mentions]
         ^{:key (str "search-" tag)}
         [:span.mention tag])])))

(defn editor-state
  "Create editor-state, either from deserialized state or from search string."
  [q]
  (if-let [editor-state (:editor-state q)]
    (d/editor-state-from-raw (clj->js editor-state))
    (d/editor-state-from-text (or (:search-text q) ""))))

(defn search-field-view
  "Renders search field for current tab."
  [query-id put-fn]
  (let [query-cfg (subscribe [:query-cfg])
        query (reaction (when-let [qid @query-id] (qid (:queries @query-cfg))))
        local (r/atom {:starred (:starred @query)})]
    (fn [query-id put-fn]
      (let [search-send (fn [text editor-state]
                          (let [story (first (d/entry-stories editor-state))
                                s (merge @query
                                         (p/parse-search text)
                                         {:story        story
                                          :editor-state editor-state})]
                            (put-fn [:search/update s])))
            query @query
            starred (:starred query)
            star-fn #(put-fn [:search/update (update-in query [:starred] not)])]
        (when-not (:briefing query)
          [:div.search
           [tags-view query]
           [:div.search-row
            [d/draft-search-field (editor-state query) search-send]
            [:div [:span.fa
                   {:class    (if starred "fa-star starred" "fa-star-o")
                    :on-click star-fn}]]]])))))
