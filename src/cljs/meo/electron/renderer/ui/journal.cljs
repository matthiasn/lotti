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
        entries-map (subscribe [:entries-map])
        results (subscribe [:results])
        gql-res (subscribe [:gql-res])
        tab-group (:tab-group local-cfg)
        entries-list (reaction (get-in @gql-res [:tabs-query :data tab-group]))]
    (fn journal-view-render [local-cfg put-fn]
      (let [conf (merge @cfg @options)
            query-id (:query-id local-cfg)
            entries (query-id @results)
            entries-map-deref @entries-map
            entries (map (fn [ts] (get entries-map-deref ts)) entries)
            get-or-retrieve (u/find-missing-entry entries-map put-fn)
            show-pvt? (:show-pvt conf)
            filtered-entries (if show-pvt?
                               entries
                               (filter (u/pvt-filter conf @entries-map) entries))
            show-context? (:show-context conf)
            comments-w-entries? (not (:comments-standalone conf))
            with-comments? (fn [entry] (and (or (and comments-w-entries?
                                                     (not (:comment-for entry)))
                                                (not comments-w-entries?))
                                            (or (:new-entry entry) show-context?)))]
        (doseq [x @entries-list] (get-or-retrieve (:timestamp x)))
        [:div.journal
         [:div.journal-entries
          (when-let [story (:story local-cfg)]
            (put-fn [:entry/find {:timestamp story}])
            (when (get entries-map-deref story)
              ^{:key (str "story" story)}
              [e/entry-with-comments story put-fn local-cfg]))
          (for [entry @entries-list]
            (when (with-comments? entry)
              ^{:key (:timestamp entry)}
              [e/entry-with-comments (:timestamp entry) put-fn local-cfg]))
          #_
          (for [entry filtered-entries]
            (when (with-comments? entry)
              ^{:key (:timestamp entry)}
              [e/entry-with-comments (:timestamp entry) put-fn local-cfg]))

          (when (> (count entries) 1)
            (let [show-more #(put-fn [:show/more {:query-id query-id}])]
              [:div.show-more {:on-click show-more :on-mouse-over show-more}
               [:span.show-more-btn [:i.far.fa-plus-square] " show more"]]))]]))))
