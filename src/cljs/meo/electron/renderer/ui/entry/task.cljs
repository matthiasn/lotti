(ns meo.electron.renderer.ui.entry.task
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [taoensso.timbre :refer-macros [info debug]]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [clojure.set :as set]))

(defn task-details [entry local-cfg put-fn edit-mode?]
  (let [local (r/atom {:show false})]
    (fn [entry local-cfg put-fn edit-mode?]
      (when (or (contains? (set (:perm_tags entry)) "#task")
                (contains? (set (:tags entry)) "#task"))
        (let [prio-select (fn [entry]
                            (fn [ev]
                              (let [sel (keyword (h/target-val ev))
                                    updated (assoc-in entry [:task :priority] sel)]
                                (put-fn [:entry/update-local updated]))))
              done (fn [entry]
                     (fn [_ev]
                       (let [completion-ts (.format (moment))
                             entry (-> entry
                                       (assoc-in [:task :completion-ts] completion-ts)
                                       (update-in [:task :done] not))
                             set-fn (if (get-in entry [:task :done])
                                      set/union
                                      set/difference)
                             entry (-> entry
                                       (update-in [:perm_tags] set-fn #{"#done"})
                                       (update-in [:tags] set-fn #{"#done"}))]
                         (put-fn [:entry/update entry]))))
              hold (fn [entry]
                     (fn [_ev]
                       (let [updated (update-in entry [:task :on_hold] not)]
                         (put-fn [:entry/update updated]))))
              allocation (or (get-in entry [:task :estimate_m]) 0)
              priority (get-in entry [:task :priority])
              done-checked (get-in entry [:task :done])
              hold-checked (get-in entry [:task :on_hold])
              ]
          [:form.task-details
           [:div
            [:div.overview
             [:span.click {:class    (when done-checked "done")
                           :on-click (done entry)}
              [:i.fas.fa-check]]
             #_[:span.click {:class    (when hold-checked "hold")
                             :on-click (hold entry)}
                [:i.fas.fa-ban]]
             [:span.click {:on-click #(swap! local update-in [:show] not)}
              [:i.fas.fa-cog]]
             ]]
           (when (:show @local)
             [:fieldset
              [:div
               [:label " Priority: "]
               [:select {:value     (if priority (keyword priority) "")
                         :on-change (prio-select entry)}
                [:option ""]
                [:option {:value :A} "A"]
                [:option {:value :B} "B"]
                [:option {:value :C} "C"]
                [:option {:value :D} "D"]
                [:option {:value :E} "E"]]]
              [:div
               [:label "Done? "]
               [:input {:type      :checkbox
                        :checked   (get-in entry [:task :done])
                        :on-change (done entry)}]]
              [:div
               [:label "On hold? "]
               [:input {:type      :checkbox
                        :checked   (get-in entry [:task :on_hold])
                        :on-change (hold entry)}]]
              [:div
               [:label "Reward points: "]
               [:input {:type      :number
                        :on-change (h/update-numeric entry [:task :points] put-fn)
                        :value     (get-in entry [:task :points] 0)}]]
              [:div
               [:label "Allocation: "]
               [:input {:on-change (h/update-time entry [:task :estimate_m] put-fn)
                        :value     (when allocation
                                     (h/m-to-hh-mm allocation))
                        :type      :time}]]])])))))
