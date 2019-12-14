(ns meins.electron.renderer.ui.entry.task
  (:require ["moment" :as moment]
            [clojure.pprint :as pp]
            [clojure.set :as set]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug info]]))

(defn allocation-row [entry]
  (let [allocation (h/m-to-hh-mm (or (get-in entry [:task :estimate_m]) 0))
        local (r/atom {:value allocation})]
    (fn [entry]
      (let [on-change (fn [ev]
                        (let [f (h/update-time entry [:task :estimate_m])
                              v (f ev)]
                          (swap! local assoc :value v)))]
        [:div.row
         [:label "Allocation: "]
         [:input {:on-change   on-change
                  :on-key-down (h/key-down-save entry)
                  :value       (:value @local)
                  :type        :time}]]))))

(defn task-details [_entry]
  (let [local (r/atom {:show false})]
    (fn [entry]
      (let [prio-select (fn [entry]
                          (fn [ev]
                            (let [sel (keyword (h/target-val ev))
                                  updated (assoc-in entry [:task :priority] sel)]
                              (emit [:entry/update-local updated]))))
            clear (fn [entry]
                    (let [ks #{:done :closed :on_hold :completion_ts :closed_ts :hold_ts}]
                      (-> entry
                          (update-in [:task] #(apply dissoc % ks))
                          (update-in [:tags] disj "#done" "#closed")
                          (update-in [:perm_tags] disj "#done" "#closed"))))
            done (fn [entry]
                   (fn [_ev]
                     (let [completion-ts (.format (moment))
                           checked (get-in entry [:task :done])
                           entry (-> entry
                                     clear
                                     (assoc-in [:task :completion_ts] completion-ts)
                                     (assoc-in [:task :done] (not checked)))
                           set-fn (if (get-in entry [:task :done])
                                    set/union
                                    set/difference)
                           entry (-> entry
                                     (update-in [:perm_tags] set-fn #{"#done"})
                                     (update-in [:tags] set-fn #{"#done"}))]
                       (emit [:entry/update entry]))))
            close (fn [entry]
                    (fn [_ev]
                      (let [rejection-ts (.format (moment))
                            checked (get-in entry [:task :closed])
                            entry (-> entry
                                      clear
                                      (assoc-in [:task :closed_ts] rejection-ts)
                                      (assoc-in [:task :closed] (not checked)))
                            set-fn (if (get-in entry [:task :closed])
                                     set/union
                                     set/difference)
                            entry (-> entry
                                      (update-in [:perm_tags] set-fn #{"#closed"})
                                      (update-in [:tags] set-fn #{"#closed"}))]
                        (emit [:entry/update entry]))))
            priority (get-in entry [:task :priority])
            done-checked (get-in entry [:task :done])
            closed (get-in entry [:task :closed])]
        [:div.task-details
         [:div.overview
          [:span.click {:class    (when done-checked "done")
                        :on-click (done entry)}
           [:i.fas.fa-check-circle]]
          [:span.click {:class    (when closed "closed")
                        :on-click (close entry)}
           [:i.fas.fa-times-circle]]
          [:span.click {:on-click #(swap! local update-in [:show] not)}
           [:i.fas.fa-cog]]]
         (when (:show @local)
           [:div.details
            [:h3 "Task details"]
            [:div.row
             [:label " Priority: "]
             [:select {:value       (if priority (keyword priority) "")
                       :on-change   (prio-select entry)
                       :on-key-down (h/key-down-save entry)}
              [:option ""]
              [:option {:value :A} "A"]
              [:option {:value :B} "B"]
              [:option {:value :C} "C"]
              [:option {:value :D} "D"]
              [:option {:value :E} "E"]]]
            [:div.row
             [:label "Done? "]
             [uc/switch {:entry    entry
                         :path     [:task :done]
                         :on-click (done entry)}]]
            [:div.row
             [:label "Closed? "]
             [uc/switch {:entry    entry
                         :path     [:task :closed]
                         :on-click (close entry)}]]
            [:div.row
             [:label "On hold? "]
             [uc/switch {:entry    entry
                         :path     [:task :on_hold]
                         :msg-type :entry/update}]]
            [:div.row
             [:label "Reward points: "]
             [:input {:type        :number
                      :on-change   (h/update-numeric entry [:task :points])
                      :on-key-down (h/key-down-save entry)
                      :value       (get-in entry [:task :points] 0)}]]
            [allocation-row entry]])]))))
