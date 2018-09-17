(ns meo.electron.renderer.ui.virtualized
  (:require [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.entry :as e]
            [re-frame.core :refer [subscribe]]
            [react-virtualized :refer [List]]
            [reagent.core :as r]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]))

(def virtualized-list (r/adapt-react-class List))

(defn item [props]
  (let [props (js->clj props)
        idx (get props "index")]
    (r/as-element
      ^{:key idx}
      [:div {:style {:background-color :white}
             :key   idx}
       [:h1 idx]
       (str props)])))

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
            tg (:tab-group local-cfg)
            show-context? (:show-context conf)
            comments-w-entries? (not (:comments-standalone conf))
            with-comments? (fn [entry] (and (or (and comments-w-entries?
                                                     (not (:comment_for entry)))
                                                (not comments-w-entries?))
                                            (or (:new-entry entry) show-context?)))]
        ^{:key (str query-id)}
        [:div.journal
         {:on-mouse-enter #(put-fn [:search/cmd {:t         :active-tab
                                                 :tab-group tg}])}
         [:div.journal-entries
          "foooooo"
          [virtualized-list {:width       350
                             :height      500
                             :rowCount    100
                             :rowHeight   50
                             :rowRenderer item}]
          #_(for [entry @entries-list]
              (when (with-comments? entry)
                ^{:key (str (:timestamp entry) (:vclock entry))}
                [e/entry-with-comments entry put-fn local-cfg]))
          (when (> (count @entries-list) 1)
            (let [show-more #(put-fn [:show/more {:query-id query-id}])]
              [:div.show-more {:on-click show-more :on-mouse-over show-more}
               [:span.show-more-btn [:i.far.fa-plus-square] " show more"]]))]]))))
