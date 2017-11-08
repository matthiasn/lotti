(ns meo.electron.renderer.ui.entry.task
  (:require [matthiasn.systems-toolbox.component :as st]
            [clojure.string :as s]
            [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]))

(defn task-details
  [entry local-cfg put-fn edit-mode?]
  (let [format-time #(.format (moment %) "ddd MMM DD - HH:mm")
        planning-mode (subscribe [:planning-mode])
        input-fn (fn [entry k]
                   (fn [ev]
                     (let [dt (moment (-> ev .-nativeEvent .-target .-value))
                           updated (assoc-in entry [:task k] (.valueOf dt))]
                       (put-fn [:entry/update-local updated]))))
        set-active-from (fn [entry]
                          (fn [ev]
                            (let [dt (-> ev .-nativeEvent .-target .-value)
                                  updated (assoc-in entry [:task :active-from] dt)]
                              (put-fn [:entry/update-local updated]))))
        prio-select (fn [entry]
                      (fn [ev]
                        (let [sel (keyword (-> ev .-nativeEvent .-target .-value))
                              updated (assoc-in entry [:task :priority] sel)]
                          (put-fn [:entry/update-local updated]))))
        close-tab (fn []
                    (when (= (str (:timestamp entry)) (:search-text local-cfg))
                      (put-fn [:search/remove local-cfg])))
        done (fn [entry]
               (fn [ev]
                 (let [completion-ts (.format (moment))
                       updated (-> entry
                                   (assoc-in [:task :completion-ts] completion-ts)
                                   (update-in [:task :done] not))]
                   (put-fn [:entry/update updated])
                   (close-tab))))
        hold (fn [entry]
               (fn [ev]
                 (let [updated (update-in entry [:task :on-hold] not)]
                   (put-fn [:entry/update updated]))))]
    (fn [entry local-cfg put-fn edit-mode?]
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
                     :on-change (hold entry)}]]
           #_#_
           [:span " Due: "]
           (if edit-mode?
             [:input {:type     :datetime-local
                      :on-input (input-fn entry :due)
                      :value    (h/format-time (-> entry :task :due))}]
             [:time (format-time (-> entry :task :due))])]
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
                    :value     (get-in entry [:task :estimate-m] 0)}]]
          #_
          (let [active-from (get-in entry [:task :active-from])]
            (when (or edit-mode? active-from)
              [:div
               [:label "Active from: "]
               [:input {:type      :datetime-local
                        :read-only (not edit-mode?)
                        :on-input  (set-active-from entry)
                        :value     (or active-from "")}]]))]]))))
