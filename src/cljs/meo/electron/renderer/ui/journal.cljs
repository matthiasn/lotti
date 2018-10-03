(ns meo.electron.renderer.ui.journal
  (:require [meo.electron.renderer.ui.entry.entry :as e]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [react-list :as rl]
            [reagent.core :as r]
            [matthiasn.systems-toolbox.component :as st]))

(def react-list (r/adapt-react-class rl))

(defn entry-wrapper [idx local-cfg _put-fn]
  (let [tab-group (:tab-group local-cfg)
        gql-res (subscribe [:gql-res2])
        entry (reaction (-> @gql-res
                            (get tab-group)
                            vals
                            (nth idx)))]
    (fn entry-wrapper-render [_idx local-cfg put-fn]
      ^{:key (str (:timestamp @entry) (:vclock @entry))}
      [:div
       (when @entry
         [e/entry-with-comments @entry put-fn local-cfg])])))

(defn item [local-cfg put-fn]
  (fn [idx]
    (r/as-element
      [:div {:key idx}
       [entry-wrapper idx local-cfg put-fn]])))

(defn journal-view
  "Renders journal div, one entry per item, with map if geo data exists in the
   entry."
  [local-cfg _put-fn]
  (let [gql-res (subscribe [:gql-res2])
        local (r/atom {:last-cnt 0
                       :last-fetch 0})
        tab-group (:tab-group local-cfg)
        entries-list (reaction (vals (get-in @gql-res [tab-group])))]
    (fn journal-view-render [local-cfg put-fn]
      (let [query-id (:query-id local-cfg)
            tg (:tab-group local-cfg)
            cnt (count @entries-list)
            on-scroll (fn [ev]
                        (let [elem (-> ev .-nativeEvent .-srcElement)
                              sh (.-scrollHeight elem)
                              st (.-scrollTop elem)
                              th (+ 1000 (* sh 0.2))]
                          (when (and (not= cnt (:last-cnt @local))
                                     (< (- sh st) th)
                                     (> (- (st/now) (:last-fetch @local)) 1000))
                            (reset! local {:last-cnt cnt
                                           :last-fetch (st/now)})
                            (put-fn [:show/more {:query-id query-id
                                                 :tab-group tg}]))))
            on-mouse-enter #(put-fn [:search/cmd {:t         :active-tab
                                                  :tab-group tg}])]
        ^{:key (str query-id)}
        [:div.journal {:on-mouse-enter on-mouse-enter}
         [:div.journal-entries {:on-scroll on-scroll}
          [react-list {:length       (count @entries-list)
                       :itemRenderer (item local-cfg put-fn)}]]]))))
