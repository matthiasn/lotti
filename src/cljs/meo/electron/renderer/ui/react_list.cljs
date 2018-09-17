(ns meo.electron.renderer.ui.react-list
  (:require [meo.common.utils.misc :as u]
            [meo.electron.renderer.ui.entry.entry :as e]
            [re-frame.core :refer [subscribe]]
            [react-list :as rl]
            [reagent.core :as r]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]))

(def react-list (r/adapt-react-class rl))

(defn item [entries-list local-cfg put-fn]
  (fn [idx]
    (let [entry (get @entries-list idx)]
      (r/as-element
        ^{:key idx}
        [:div {:style {:background-color :white}
               :key   idx}
         [e/entry-with-comments entry put-fn local-cfg]]))))

(defn journal-view
  "Renders journal div, one entry per item, with map if geo data exists in the
   entry."
  [local-cfg put-fn]
  (let [gql-res (subscribe [:gql-res])
        tab-group (:tab-group local-cfg)
        entries-list (reaction (get-in @gql-res [:tabs-query :data tab-group]))]
    (fn journal-view-render [local-cfg put-fn]
      (let [query-id (:query-id local-cfg)
            tg (:tab-group local-cfg)
            on-scroll (fn [ev]
                        (let [elem (-> ev .-nativeEvent .-srcElement)
                              sh (.-scrollHeight elem)
                              st (.-scrollTop elem)]
                          (info :sh sh :st st)
                          (when (< (- sh st) 1000)
                            (put-fn [:show/more {:query-id query-id}]))))]
        ^{:key (str query-id)}
        [:div.journal
         {:on-mouse-enter #(put-fn [:search/cmd {:t         :active-tab
                                                 :tab-group tg}])}
         [:div.journal-entries {:on-scroll on-scroll}
          [react-list {:length       (count @entries-list)
                       :itemRenderer (item entries-list local-cfg put-fn)}]]]))))
