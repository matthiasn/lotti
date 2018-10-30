(ns meo.electron.renderer.ui.entry.task
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [taoensso.timbre :refer-macros [info debug]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [clojure.set :as set]
            [clojure.pprint :as pp]
            [meo.electron.renderer.ui.ui-components :as uc]))

(defn task-details [entry local-cfg put-fn edit-mode?]
  (let [local (r/atom {:show false})]
    (fn [entry local-cfg put-fn edit-mode?]
      (let [prio-select (fn [entry]
                          (fn [ev]
                            (let [sel (keyword (h/target-val ev))
                                  updated (assoc-in entry [:task :priority] sel)]
                              (put-fn [:entry/update-local updated]))))
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
                       (put-fn [:entry/update entry]))))
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
                        (put-fn [:entry/update entry]))))
            allocation (or (get-in entry [:task :estimate_m]) 0)
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
             [:select {:value     (if priority (keyword priority) "")
                       :on-change (prio-select entry)}
              [:option ""]
              [:option {:value :A} "A"]
              [:option {:value :B} "B"]
              [:option {:value :C} "C"]
              [:option {:value :D} "D"]
              [:option {:value :E} "E"]]]
            [:div.row
             [:label "Done? "]
             [uc/switch {:entry    entry
                         :put-fn   put-fn
                         :path     [:task :done]
                         :on-click (done entry)}]]
            [:div.row
             [:label "Closed? "]
             [uc/switch {:entry    entry
                         :put-fn   put-fn
                         :path     [:task :closed]
                         :on-click (close entry)}]]
            [:div.row
             [:label "On hold? "]
             [uc/switch {:entry    entry
                         :put-fn   put-fn
                         :path     [:task :on_hold]
                         :msg-type :entry/update}]]
            [:div.row
             [:label "Reward points: "]
             [:input {:type      :number
                      :on-change (h/update-numeric entry [:task :points] put-fn)
                      :value     (get-in entry [:task :points] 0)}]]
            [:div.row
             [:label "Allocation: "]
             [:input {:on-change (h/update-time entry [:task :estimate_m] put-fn)
                      :value     (when allocation
                                   (h/m-to-hh-mm allocation))
                      :type      :time}]]])]))))
