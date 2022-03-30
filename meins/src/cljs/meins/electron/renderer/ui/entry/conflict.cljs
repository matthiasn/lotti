(ns meins.electron.renderer.ui.entry.conflict
  (:require [cljs.pprint :as pp]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn conflict-view [_entry]
  (let [local (r/atom {})]
    (fn [entry]
      (when-let [conflict (:conflict entry)]
        (when-not (contains? #{:resolved-theirs :resolved-ours} conflict)
          (let [ours (fn [_]
                       (let [updated (assoc entry :conflict :resolved-ours)]
                         (debug updated)
                         (emit [:entry/update updated])))
                theirs (fn [_]
                         (let [updated (assoc entry :conflict :resolved-theirs)
                               merge-fn (fn [a b]
                                          (if (and (map? a) (map? b))
                                            (merge a b)
                                            b))
                               updated (merge-with merge-fn updated conflict)]
                           (debug updated)
                           (emit [:entry/update updated])))]
            [:div.conflict
             [:div.warn [:span.fa.fa-exclamation] "Conflict"]
             [:div
              [:h3 "Theirs:"]
              [:div (:md conflict)]
              [:pre {:on-click #(swap! local update :confirm-theirs not)}
               [:code (with-out-str (pp/pprint (:vclock conflict)))]]
              (when (:confirm-theirs @local)
                [:button {:on-click theirs}
                 "confirm theirs"])]
             [:div
              [:h3 "Ours:"]
              [:pre {:on-click #(swap! local update :confirm-ours not)}
               [:code (with-out-str (pp/pprint (:vclock entry)))]]
              (when (:confirm-ours @local)
                [:button {:on-click ours}
                 "confirm ours"])]]))))))

