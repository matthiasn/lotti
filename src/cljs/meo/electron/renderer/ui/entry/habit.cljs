(ns meo.electron.renderer.ui.entry.habit
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]))

(defn next-habit-entry
  "Generate next habit entry, as appropriate at the time of calling.
   Store this to actually create entry."
  [entry]
  (let [next-hh-mm (-> entry :habit :active_from (moment) (h/hh-mm))
        active-days (filter identity (map (fn [[k v]] (when v k))
                                          (get-in entry [:habit :days])))
        active-days (concat active-days (map #(+ % 7) active-days))
        active-days (filter number? active-days)
        current-day (.day (moment))
        next-day-int (first (drop-while #(>= current-day %) active-days))
        next-day (h/ymd (.add (moment) (- next-day-int current-day) "d"))
        next-active (str next-day "T" next-hh-mm)]
    (-> entry
        (assoc-in [:timestamp] (st/now))
        (assoc-in [:habit :active_from] next-active)
        (assoc-in [:habit :done] false)
        (dissoc :linked-entries-list)
        (dissoc :linked_entries_list)
        (dissoc :last_saved)
        (dissoc :geoname)
        (dissoc :latitude)
        (dissoc :longitude))))

(defn habit-details [entry local-cfg put-fn edit-mode?]
  (let [ts (:timestamp entry)
        backend-cfg (subscribe [:backend-cfg])
        active-from (fn [entry]
                      (fn [ev]
                        (let [dt (h/target-val ev)
                              updated (assoc-in entry [:habit :active_from] dt)]
                          (put-fn [:entry/update-local updated]))))
        day-select (fn [entry day]
                     (fn [_ev]
                       (let [updated (update-in entry [:habit :days day] not)]
                         (put-fn [:entry/update-local updated]))))
        day-checkbox (fn [entry day]
                       [:input {:type      :checkbox
                                :checked   (get-in entry [:habit :days day])
                                :on-change (day-select entry day)}])
        close-tab #(put-fn [:search/remove-all {:search-text (str ts)}])
        done
        (fn [entry]
          (fn [ev]
            (if-not (-> entry :habit :next-entry)
              ;; check off and create next habit entry
              (let [next-entry (next-habit-entry entry)
                    completion-ts (.format (moment))
                    next-ts (:timestamp next-entry)
                    updated (-> entry
                                (assoc-in [:habit :next-entry] next-ts)
                                (assoc-in [:habit :completion_ts] completion-ts)
                                (update-in [:habit :done] not))]
                (put-fn [:entry/update next-entry])
                (put-fn [:entry/update updated])
                (close-tab))
              ;; otherwise just toggle - follow-up is scheduled already
              (let [updated (update-in entry [:habit :done] not)]
                (put-fn [:entry/update updated])))))
        skipped
        (fn [entry]
          (fn [ev]
            (if-not (-> entry :habit :next-entry)
              ;; check off and create next habit entry
              (let [next-entry (next-habit-entry entry)
                    next-ts (:timestamp next-entry)
                    updated (-> entry
                                (assoc-in [:habit :next-entry] next-ts)
                                (update-in [:habit :skipped] not))]
                (put-fn [:entry/update next-entry])
                (put-fn [:entry/update updated])
                (close-tab))
              ;; otherwise just toggle - follow-up is scheduled already
              (let [updated (update-in entry [:habit :skipped] not)]
                (put-fn [:entry/update updated])))))
        set-points (fn [entry point-type]
                     (fn [ev]
                       (let [v (.. ev -target -value)
                             parsed (when (seq v) (js/parseFloat v))
                             updated (assoc-in entry [:habit point-type] parsed)]
                         (when parsed
                           (put-fn [:entry/update-local updated])))))
        priority-select
        (fn [entry]
          (fn [ev]
            (let [sel (keyword (h/target-val ev))
                  updated (assoc-in entry [:habit :priority] sel)]
              (put-fn [:entry/update-local updated]))))]
    (fn [entry local-cfg put-fn edit-mode?]
      (when (contains? (:tags entry) "#habit")
        (when (and edit-mode? (not (:habit entry)))
          (let [active-from (h/format-time (st/now))
                habit {:days        (zipmap (range 7) (repeat true))
                       :priority    :B
                       :points      10
                       :penalty     10
                       :active_from active-from
                       :done        false}
                updated (assoc-in entry [:habit] habit)]
            (put-fn [:entry/update-local updated])))
        (when (contains? (:capabilities @backend-cfg) :habits)
          [:form.habit-details
           [:fieldset
            [:legend "Habit details"]
            [:div
             [:label "Sun"] [day-checkbox entry 0]
             [:label "Mon"] [day-checkbox entry 1]
             [:label "Tue"] [day-checkbox entry 2]
             [:label "Wed"] [day-checkbox entry 3]
             [:label "Thu"] [day-checkbox entry 4]
             [:label "Fri"] [day-checkbox entry 5]
             [:label "Sat"] [day-checkbox entry 6]]
            [:div
             [:span " Priority: "]
             [:select {:value     (get-in entry [:habit :priority] "")
                       :disabled  (not edit-mode?)
                       :on-change (priority-select entry)}
              [:option ""]
              [:option {:value :A} "A"]
              [:option {:value :B} "B"]
              [:option {:value :C} "C"]
              [:option {:value :D} "D"]
              [:option {:value :E} "E"]]
             [:label "Active: "]
             [:input {:type      :datetime-local
                      :on-change (active-from entry)
                      :value     (get-in entry [:habit :active_from])}]]
            [:div
             [:label [:span.fa.fa-gem.bonus]]
             [:input {:type      :number
                      :on-change (set-points entry :points)
                      :value     (get-in entry [:habit :points] 0)}]
             [:label [:span.fa.fa-gem.penalty]]
             [:input {:type      :number
                      :on-change (set-points entry :penalty)
                      :value     (get-in entry [:habit :penalty] 0)}]]
            [:div
             [:label "Done? "]
             [:input {:type      :checkbox
                      :checked   (get-in entry [:habit :done])
                      :on-change (done entry)}]
             [:label "Skipped? "]
             [:input {:type      :checkbox
                      :checked   (get-in entry [:habit :skipped])
                      :on-change (skipped entry)}]]]])))))
