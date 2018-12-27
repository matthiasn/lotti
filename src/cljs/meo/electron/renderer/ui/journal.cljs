(ns meo.electron.renderer.ui.journal
  (:require [meo.electron.renderer.ui.entry.entry :as e]
            [taoensso.timbre :refer [info error debug]]
            [reagent.ratom :refer-macros [reaction]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [react-list :as rl]
            [reagent.core :as r]
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.helpers :as h]))

(def react-list (r/adapt-react-class rl))

(defn entry-wrapper [idx local-cfg ]
  (let [tab-group (:tab-group local-cfg)
        gql-res (subscribe [:gql-res2])
        entry (reaction (-> @gql-res
                            (get tab-group)
                            :res
                            vals
                            (nth idx)))]
    (fn entry-wrapper-render [_idx local-cfg ]
      ^{:key (str (count (:comments entry)) (:vclock @entry))}
      [:div
       (when @entry
         [e/entry-with-comments @entry local-cfg])])))

(defn item [local-cfg]
  (fn [idx]
    (r/as-element
      [:div {:key idx}
       [h/error-boundary
        [entry-wrapper idx local-cfg]]])))

(defn journal-view
  "Renders journal div, one entry per item, with map if geo data exists in the
   entry."
  [local-cfg]
  (let [gql-res (subscribe [:gql-res2])
        local (r/atom {:last-cnt   0
                       :last-fetch 0})
        tab-group (:tab-group local-cfg)
        entries-list (reaction (vals (get-in @gql-res [tab-group :res])))]
    (fn journal-view-render [local-cfg]
      (let [query-id (:query-id local-cfg)
            tg (:tab-group local-cfg)
            cnt (count @entries-list)
            on-scroll (fn [ev]
                        (let [elem (-> ev .-nativeEvent .-srcElement)
                              sh (.-scrollHeight elem)
                              st (.-scrollTop elem)
                              th (+ 1000 (* sh 0.2))]
                          (when (and (or (< (- sh st) th)
                                         (< (- sh st) (* 0.2 sh)))
                                     (> (- (st/now) (:last-fetch @local)) 1000))
                            (reset! local {:last-cnt   cnt
                                           :last-fetch (st/now)})
                            (emit [:show/more {:query-id  query-id
                                                 :tab-group tg}]))))
            on-mouse-enter #(emit [:search/cmd {:t         :active-tab
                                                  :tab-group tg}])]
        ^{:key (str query-id)}
        [:div.journal {:on-mouse-enter on-mouse-enter}
         [h/error-boundary
          [:div.journal-entries {:on-scroll on-scroll
                                 :id        (name tab-group)}
           [react-list {:length       (count @entries-list)
                        :itemRenderer (item local-cfg)}]]]]))))

(def interval (atom nil))
(defn scroll-down [id h]
  (let [elem (.getElementById js/document id)
        st (.-scrollTop elem)]
    (aset elem "scrollTop" (+ st h))))

(defn playback [id h]
  (reset! interval (js/setInterval #(scroll-down id h) 16)))

(defn stop-playback []
  (when @interval
    (js/clearInterval @interval)))

;(def ^:export scrollStart playback)
;(def ^:export scrollStop stop-playback)
