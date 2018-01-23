(ns meo.electron.renderer.ui.entry.task
  (:require [matthiasn.systems-toolbox.component :as st]
            [clojure.string :as s]
            [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]))

(defn task-details
  [entry local-cfg put-fn _edit-mode?]
  (let [planning-mode (subscribe [:planning-mode])
        prio-select (fn [entry]
                      (fn [ev]
                        (let [sel (keyword (h/target-val ev))
                              updated (assoc-in entry [:task :priority] sel)]
                          (put-fn [:entry/update-local updated]))))
        close-tab (fn []
                    (when (= (str (:timestamp entry)) (:search-text local-cfg))
                      (put-fn [:search/remove local-cfg])))
        done (fn [entry]
               (fn [_ev]
                 (let [completion-ts (.format (moment))
                       updated (-> entry
                                   (assoc-in [:task :completion-ts] completion-ts)
                                   (update-in [:task :done] not))]
                   (put-fn [:entry/update updated])
                   (close-tab))))
        hold (fn [entry]
               (fn [_ev]
                 (let [updated (update-in entry [:task :on-hold] not)]
                   (put-fn [:entry/update updated]))))]
    (fn [entry _local-cfg put-fn edit-mode?]
      (when (and (contains? (:tags entry) "#task") @planning-mode)
        (when (and edit-mode? (not (:task entry)))
          (let [d (* 24 60 60 1000)
                now (st/now)
                updated (assoc-in entry [:task] {:due (+ now d d)})]
            (put-fn [:entry/update-local updated])))
        [:form.task-details
         [:fieldset
          [:legend "Task details"]
          [:div
           [:span " Priority: "]
           [:select {:value     (get-in entry [:task :priority] "")
                     ;:disabled  (not edit-mode?)
                     :on-change (prio-select entry)}
            [:option ""]
            [:option {:value :A} "A"]
            [:option {:value :B} "B"]
            [:option {:value :C} "C"]
            [:option {:value :D} "D"]
            [:option {:value :E} "E"]]
           [:span
            [:label "Done? "]
            [:input {:type      :checkbox
                     :checked   (get-in entry [:task :done])
                     :on-change (done entry)}]
            [:label "On hold? "]
            [:input {:type      :checkbox
                     :checked   (get-in entry [:task :on-hold])
                     :on-change (hold entry)}]]]
          [:span
           [:label "Reward points: "]
           [:input {:type      :number
                    :read-only (not edit-mode?)
                    :on-input  (h/update-numeric entry [:task :points] put-fn)
                    :value     (get-in entry [:task :points] 0)}]
           [:label "Estimated min: "]
           [:input {:type      :number
                    :read-only (not edit-mode?)
                    :on-input  (h/update-numeric entry [:task :estimate-m] put-fn)
                    :value     (get-in entry [:task :estimate-m] 0)}]]]]))))
