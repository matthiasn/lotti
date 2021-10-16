(ns meins.electron.renderer.ui.entry.cfg.habit
  (:require [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.misc :as m]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn a-z [x] (m/lower-case (second x)))

(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [entry idx version]}]
      (let [q-tags (-> @backend-cfg :questionnaires :mapping)
            path [:habit:versions version :criteria idx :quest-k]]
        [:div
         [:h4 "Questionnaire filled on desired schedule"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      path
                      :xf        keyword
                      :sorted-by a-z
                      :options   (zipmap (vals q-tags)
                                         (keys q-tags))}]]
         [:div.row
          [:label.wide "Required n:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      [:habit :criteria version idx :req-n]
                      :xf        js/parseInt
                      :options   [1 2 3 4 5 6 7]}]]]))))

(defn min-max-sum [{:keys []}]
  (let [backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn [{:keys [entry idx version]}]
      (let [cf-path [:habit :versions version :criteria idx :cf-tag]
            cf-tag (get-in entry cf-path "")
            cfk-path [:habit :versions version :criteria idx :cf-key]
            k (get-in entry cfk-path)
            fields (get-in @custom-fields [cf-tag :fields])
            min-path [:habit :versions version :criteria idx :min-val]
            max-path [:habit :versions version :criteria idx :max-val]
            field-cfg (get-in fields [k :cfg])
            custom-fields (vec @custom-fields)
            tags (if @pvt
                   custom-fields
                   (filter #(not (:pvt (second %))) custom-fields))]
        [:div
         [:h4 "Custom field values summed, within min/max range"]
         [:div.row
          [:label "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      cf-path
                      :sorted-by a-z
                      :options   (map first tags)}]]
         (when (seq (name cf-tag))
           (let [opts (map (fn [[k v]] [k (:label v)]) fields)]
             [:div.row
              [:label "Key:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
                          :path      cfk-path
                          :xf        keyword
                          :options   (into {} opts)}]]))
         (when (seq (str k))
           [cs/input-row entry (merge field-cfg
                                      {:label "Minimum:"
                                       :path  min-path}) emit])
         (when (seq (str k))
           [cs/input-row entry (merge field-cfg
                                      {:label "Maximum:"
                                       :path  max-path}) emit])]))))

(defn min-max-time [{:keys []}]
  (let [sagas (subscribe [:sagas])
        pvt (subscribe [:show-pvt])
        stories (subscribe [:stories])]
    (fn [{:keys [entry idx version]}]
      (let [saga-path [:habit :versions version :criteria idx :saga]
            saga (get-in entry saga-path "")
            sagas (filter #(:active (second %)) @sagas)
            sagas (if @pvt sagas (filter #(not (:pvt (second %))) sagas))
            sagas (into {} (map (fn [[k v]] [k (:saga_name v)]) sagas))
            story-path [:habit :versions version :criteria idx :story]
            min-path [:habit :versions version :criteria idx :min-time]
            max-path [:habit :versions version :criteria idx :max-time]]
        [:div
         [:h4 "Time spent as desired, within range"]
         [:div.row
          [:label "Saga:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      saga-path
                      :xf        js/parseInt
                      :sorted-by a-z
                      :options   sagas}]]
         (when (number? saga)
           (let [stories (filter #(and (= saga (:timestamp (:saga (second %))))
                                       (:active (second %)))
                                 @stories)
                 stories (if @pvt stories (filter #(not (:pvt (second %))) stories))
                 stories (into {} (map (fn [[k v]] [k (:story_name v)]) stories))]
             [:div.row
              [:label "Story:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
                          :path      story-path
                          :xf        js/parseInt
                          :sorted-by a-z
                          :options   stories}]]))
         (when (number? saga)
           [cs/input-row entry {:label "Minimum:"
                                :type  :time
                                :path  min-path} emit])
         (when (number? saga)
           [cs/input-row entry {:label "Maximum:"
                                :type  :time
                                :path  max-path} emit])]))))

(defn criterion [{:keys [entry idx version] :as params}]
  (let [path [:habit :versions version :criteria idx :type]
        habit-type (get-in entry path)
        rm-click (fn []
                   (let [rm #(let [criteria %]
                               (vec (concat (take idx criteria)
                                            (drop (inc idx) criteria))))
                         updated (update-in entry [:habit :versions version :criteria] rm)]
                     (emit [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt
      {:on-click rm-click}]
     (when-not habit-type
       [:div.row
        [:label "Habit Type:"]
        [uc/select {:on-change uc/select-update
                    :entry     entry
                    :path      path
                    :xf        keyword
                    :options   {:min-max-sum   "recorded data"
                                :min-max-time  "time spent"
                                ;:checked-off   "checked off"
                                :questionnaire "questionnaire"}}]])
     (when (= :min-max-sum habit-type)
       [min-max-sum params])
     (when (= :min-max-time habit-type)
       [min-max-time params])
     (when (= :questionnaire habit-type)
       [quest-details params])]))

(defn habit-details [entry]
  (let [ts (:timestamp entry)
        habits (subscribe [:habits])
        local (r/atom {})
        completions (reaction (->> (get-in @habits [ts :completed])
                                   (take 28)
                                   reverse))]
    (when (= :habit (:entry-type entry))
      (emit [:entry/update (-> entry
                               (dissoc :entry-type)
                               (assoc :entry_type :habit))]))
    (fn [entry]
      (let [versions-map (get-in entry [:habit :versions])
            mx-version (apply max (keys versions-map))
            version (or (:selected-v @local) mx-version 0)
            add-criterion (fn [entry]
                            (fn [_]
                              (let [path [:habit :versions version :criteria]
                                    updated (update-in entry path #(vec (conj % {})))]
                                (emit [:entry/update-local updated]))))
            criteria (get-in entry [:habit :versions version :criteria])
            new-version (fn [_]
                          (let [latest (get-in entry [:habit :versions mx-version])
                                path [:habit :versions (inc mx-version)]
                                updated (assoc-in entry path latest)
                                today (h/ymd (stc/now))
                                updated (assoc-in updated (conj path :valid_from) today)]
                            (emit [:entry/update updated])))]
        [:div.habit-details
         [:div.row
          [:h3.header "Habit details"]
          [:label "Version:"]
          [:select {:value     version
                    :on-change #(swap! local assoc :selected-v (js/parseInt (h/target-val %)))}
           (for [v (sort (keys versions-map))]
             ^{:key v}
             [:option v])]
          [:span.btn {:on-click new-version} "new"]]
         [cs/input-row entry {:label "Valid from:"
                              :path  [:habit :versions version :valid_from]
                              :type  :date} emit]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :path [:habit :active]}]]
         [:div.row
          [:label "Private? "]
          [uc/switch {:entry entry :path [:habit :pvt]}]]
         [:div.row
          [:label "Schedule:"]
          [uc/select {:on-change uc/select-update
                      :entry     entry
                      :path      [:habit :schedule]
                      :xf        keyword
                      :options   {:daily "per day"
                                  ;:weekly "per week"
                                  }}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-criterion entry)}
           [:i.fas.fa-plus]]]
         (for [[i _] (map-indexed (fn [i v] [i v]) criteria)]
           ^{:key i}
           [criterion {:entry   entry
                       :version version
                       :idx     i}])
         [:div.completion
          (for [[i c] (m/idxd @completions)]
            [:span.status {:class (when (:success c) "success")
                           :key   i}])]]))))
