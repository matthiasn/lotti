(ns meo.electron.renderer.ui.entry.habit
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
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
        (assoc-in [:primary_story] (-> entry :story :timestamp))
        (assoc-in [:habit :active_from] next-active)
        (assoc-in [:habit :done] false)
        (dissoc :linked-entries-list)
        (dissoc :linked_entries_list)
        (dissoc :last_saved)
        (dissoc :geoname)
        (dissoc :latitude)
        (dissoc :longitude))))

(defn habit-details [entry local-cfg put-fn edit-mode?]
  (let [backend-cfg (subscribe [:backend-cfg])
        active-from (fn [entry]
                      (fn [ev]
                        (let [dt (h/target-val ev)
                              updated (assoc-in entry [:habit :active_from] dt)]
                          (put-fn [:entry/update-local updated]))))
        day-select (fn [entry day-idx]
                     (fn [_ev]
                       (let [updated (update-in entry [:habit :days day-idx] not)]
                         (put-fn [:entry/update-local updated]))))
        day-checkbox (fn [entry day-idx day]
                       [:span.day-toggle
                        {:class    (when (get-in entry [:habit :days day-idx]) "selected")
                         :on-click (day-select entry day-idx)}
                        day])
        close-tab #(put-fn [:search/cmd {:t :close-tab}])
        done
        (fn [entry]
          (fn [ev]
            (if-not (-> entry :habit :next_entry)
              ;; check off and create next habit entry
              (let [next-entry (next-habit-entry entry)
                    completion-ts (.format (moment))
                    next-ts (:timestamp next-entry)
                    updated (-> entry
                                (assoc-in [:habit :next_entry] next-ts)
                                (assoc-in [:habit :completion_ts] completion-ts)
                                (update-in [:habit :done] not))]
                (close-tab)
                (put-fn [:entry/update next-entry])
                (put-fn [:entry/update updated]))
              ;; otherwise just toggle - follow-up is scheduled already
              (let [updated (update-in entry [:habit :done] not)]
                (put-fn [:entry/update updated])))))
        skipped
        (fn [entry]
          (fn [ev]
            (if-not (-> entry :habit :next_entry)
              ;; check off and create next habit entry
              (let [next-entry (next-habit-entry entry)
                    next-ts (:timestamp next-entry)
                    updated (-> entry
                                (assoc-in [:habit :next_entry] next-ts)
                                (update-in [:habit :skipped] not))]
                (close-tab)
                (put-fn [:entry/update next-entry])
                (put-fn [:entry/update updated]))
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
      (when (not= :habit (:entry-type entry))
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
            [:legend.header "Habit details"]
            [:div.days
             [day-checkbox entry 0 "Sun"]
             [day-checkbox entry 1 "Mon"]
             [day-checkbox entry 2 "Tue"]
             [day-checkbox entry 3 "Wed"]
             [day-checkbox entry 4 "Thu"]
             [day-checkbox entry 5 "Fri"]
             [day-checkbox entry 6 "Sat"]]
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

(defn select [{:keys [options entry path on-change] :as m}]
  (let [options (if (map? options)
                  options
                  (zipmap options options))]
    [:select {:value     (get-in entry path "")
              :on-change (on-change m)}
     [:option ""]
     (for [[v t] options]
       ^{:key v}
       [:option {:value v} t])]))

(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [q-tags (-> @backend-cfg :questionnaires :mapping)
            path [:habit :criteria idx :quest-tag]
            quest-tag (get-in entry path)
            quest-select (fn [entry]
                           (fn [ev]
                             (let [sel (keyword (h/target-val ev))
                                   updated (assoc-in entry path sel)]
                               (put-fn [:entry/update-local updated]))))]
        [:div
         [:h4 "Questionnaire filled on desired schedule"]
         [:div.row
          [:label.wide "Tag:"]
          [:select {:value     quest-tag
                    :on-change (quest-select entry)}
           [:option ""]
           (for [[qt qk] q-tags]
             ^{:key qt}
             [:option {:value qt} qt])]]]))))

(defn select-update [{:keys [entry path xf put-fn]}]
  (let [xf (or xf identity)]
    (fn [ev]
      (let [tv (h/target-val ev)
            sel (if (empty? tv) tv (xf tv))
            updated (assoc-in entry path sel)]
        (put-fn [:entry/update-local updated])))))

(defn input-row [entry label cfg path put-fn]
  (let [v (get-in entry path)
        on-change (fn [ev]
                    (let [v (h/target-val ev)
                          updated (assoc-in entry path v)]
                      (put-fn [:entry/update-local updated])))]
    [:div.row
     [:label label]
     [:input (merge {:on-change on-change
                     :class     "time"
                     :value     v}
                    cfg)]]))

(defn min-max-sum [{:keys []}]
  (let [backend-cfg (subscribe [:backend-cfg])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn [{:keys [entry idx put-fn] :as params}]
      (let [cf-path [:habit :criteria idx :cf-tag]
            cf-tag (get-in entry cf-path "")
            cfk-path [:habit :criteria idx :cf-key]
            k (get-in entry cfk-path)
            fields (get-in @custom-fields [cf-tag :fields])
            min-path [:habit :criteria idx :min-val]
            max-path [:habit :criteria idx :max-val]]
        [:div
         [:h4 "Custom field values summed, within min/max range"]
         [:div.row
          [:label "Tag:"]
          [select {:entry     entry
                   :on-change select-update
                   :path      cf-path
                   :put-fn    put-fn
                   :options   (keys @custom-fields)}]]
         (when-not (empty? (name cf-tag))
           (let [opts (map (fn [[k v]] [k (:label v)]) fields)]
             [:div.row
              [:label "Key:"]
              [select {:entry     entry
                       :on-change select-update
                       :path      cfk-path
                       :xf        keyword
                       :put-fn    put-fn
                       :options   (into {} opts)}]]))
         (when-not (empty? (str k))
           [input-row entry "Minimum:" (get-in fields [k :cfg]) min-path put-fn])
         (when-not (empty? (str k))
           [input-row entry "Maximum:" (get-in fields [k :cfg]) max-path put-fn])]))))

(defn min-max-time [{:keys []}]
  (let [sagas (subscribe [:sagas])
        stories (subscribe [:stories])]
    (fn [{:keys [entry idx put-fn] :as params}]
      (let [saga-path [:habit :criteria idx :saga]
            saga (get-in entry saga-path "")
            sagas (into {} (map (fn [[k v]] [k (:saga_name v)]) @sagas))
            story-path [:habit :criteria idx :story]
            story (get-in entry story-path)
            min-path [:habit :criteria idx :min-time]
            max-path [:habit :criteria idx :max-time]]
        [:div
         [:h4 "Time spent as desired, within range"]
         [:div.row
          [:label "Saga:"]
          [select {:entry     entry
                   :on-change select-update
                   :path      saga-path
                   :put-fn    put-fn
                   :options   sagas}]]
         (when saga
           (let [stories (into {} (map (fn [[k v]] [k (:story_name v)]) @stories))]
             [:div.row
              [:label "Story:"]
              [select {:entry     entry
                       :on-change select-update
                       :path      story-path
                       :put-fn    put-fn
                       :options   stories}]]))
         (when-not (empty? story)
           [input-row entry "Minimum:" {:type :time} min-path put-fn])
         (when-not (empty? story)
           [input-row entry "Maximum:" {:type :time} max-path put-fn])]))))

(defn criterion [{:keys [entry idx put-fn] :as params}]
  (let [path [:habit :criteria idx :type]
        habit-type (get-in entry path)]
    [:div.criterion
     (when-not habit-type
       [:div.row
        [:label "Habit Type:"]
        [select {:on-change select-update
                 :entry     entry
                 :put-fn    put-fn
                 :path      path
                 :xf        keyword
                 :options   {:min-max-sum   "min/max sum"
                             :min-max-time  "min/max time"
                             :checked-off   "checked off"
                             :questionnaire "questionnaire"}}]])
     (when (= :min-max-sum habit-type)
       [min-max-sum params])
     (when (= :min-max-time habit-type)
       [min-max-time params])
     (when (= :questionnaire habit-type)
       [quest-details params])]))

(defn habit-details2 [entry put-fn]
  (let [backend-cfg (subscribe [:backend-cfg])
        add-criterion (fn [entry]
                        (fn [_]
                          (let [updated (update-in entry [:habit :criteria] #(vec (conj % {})))]
                            (put-fn [:entry/update-local updated]))))]
    (fn [entry put-fn]
      (when (contains? (:capabilities @backend-cfg) :habits)
        (let [criteria (get-in entry [:habit :criteria])
              active (get-in entry [:habit :active])
              toggle-active #(put-fn [:entry/update-local (update-in entry [:habit :active] not)])]
          [:div.habit-details
           [:h3.header "Habit details"]
           [:div.row
            [:label "Active? "]
            [:div.on-off {:on-click toggle-active}
             [:div {:class (when-not active "inactive")} "off"]
             [:div {:class (when active "active")} "on"]]]
           [:div.row
            [:label "Schedule:"]
            [select {:on-change select-update
                     :entry     entry
                     :put-fn    put-fn
                     :path      [:habit :schedule]
                     :xf        keyword
                     :options   {:daily  "per day"
                                 :weekly "per week"}}]]
           [:div.row
            [:h3 "Criteria"]
            [:div.add-criterion {:on-click (add-criterion entry)}
             [:i.fas.fa-plus]]]
           (for [[i c] (map-indexed (fn [i v] [i v]) criteria)]
             ^{:key i}
             [criterion {:entry  entry
                         :put-fn put-fn
                         :idx    i}])])))))
