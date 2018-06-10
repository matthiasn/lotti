(ns meo.electron.renderer.ui.journal
  (:require [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.entry :as e]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]))

(defn journal-view
  "Renders journal div, one entry per item, with map if geo data exists in the
   entry."
  [local-cfg put-fn]
  (let [cfg (subscribe [:cfg])
        options (subscribe [:options])
        gql-res (subscribe [:gql-res])
        tab-group (:tab-group local-cfg)
        entries-list (reaction (get-in @gql-res [:tabs-query :data tab-group]))]
    (fn journal-view-render [local-cfg put-fn]
      (let [conf (merge @cfg @options)
            query-id (:query-id local-cfg)
            show-context? (:show-context conf)
            comments-w-entries? (not (:comments-standalone conf))
            with-comments? (fn [entry] (and (or (and comments-w-entries?
                                                     (not (:comment_for entry)))
                                                (not comments-w-entries?))
                                            (or (:new-entry entry) show-context?)))]
        [:div.journal
         [:div.journal-entries
          (for [entry @entries-list]
            (when (with-comments? entry)
              ^{:key (:timestamp entry)}
              [e/entry-with-comments entry put-fn local-cfg]))
          (when (> (count @entries-list) 1)
            (let [show-more #(put-fn [:show/more {:query-id query-id}])]
              [:div.show-more {:on-click show-more :on-mouse-over show-more}
               [:span.show-more-btn [:i.far.fa-plus-square] " show more"]]))]]))))
