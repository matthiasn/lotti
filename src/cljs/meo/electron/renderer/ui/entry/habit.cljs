(ns meo.electron.renderer.ui.entry.habit
  (:require [matthiasn.systems-toolbox.component :as st]
            [moment]
            [meo.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]))


(defn input-row [entry label cfg path put-fn]
  (let [v (get-in entry path)
        t (:type cfg)
        v (if (and v (= :time t)) (h/m-to-hh-mm v) v)
        on-change (fn [ev]
                    (let [xf (if (= :number t) js/parseInt identity)
                          v (xf (h/target-val ev))
                          v (if (= :time t)
                              (.asMinutes (.duration moment v))
                              v)
                          updated (assoc-in entry path v)]
                      (put-fn [:entry/update-local updated])))]
    [:div.row
     [:label label]
     [:input (merge {:on-change on-change
                     :class     "time"
                     :value     v}
                    cfg)]]))

(defn quest-details [_]
  (let [backend-cfg (subscribe [:backend-cfg])]
    (fn [{:keys [put-fn entry idx]}]
      (let [q-tags (-> @backend-cfg :questionnaires :mapping)
            path [:habit :criteria idx :quest-k]]
        [:div
         [:h4 "Questionnaire filled on desired schedule"]
         [:div.row
          [:label.wide "Tag:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      path
                      :put-fn    put-fn
                      :xf        keyword
                      :options   (zipmap (vals q-tags)
                                         (keys q-tags))}]]
         [:div.row
          [:label.wide "Required n:"]
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      [:habit :criteria idx :req-n]
                      :xf        js/parseInt
                      :put-fn    put-fn
                      :options   [1 2 3 4 5 6 7]}]]]))))

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
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      cf-path
                      :put-fn    put-fn
                      :options   (keys @custom-fields)}]]
         (when-not (empty? (name cf-tag))
           (let [opts (map (fn [[k v]] [k (:label v)]) fields)]
             [:div.row
              [:label "Key:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
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
          [uc/select {:entry     entry
                      :on-change uc/select-update
                      :path      saga-path
                      :xf        js/parseInt
                      :put-fn    put-fn
                      :options   sagas}]]
         (when (number? saga)
           (let [stories (filter #(= saga (:timestamp (:saga (second %)))) @stories)
                 stories (into {} (map (fn [[k v]] [k (:story_name v)]) stories))]
             [:div.row
              [:label "Story:"]
              [uc/select {:entry     entry
                          :on-change uc/select-update
                          :path      story-path
                          :xf        js/parseInt
                          :put-fn    put-fn
                          :options   stories}]]))
         (when (number? story)
           [input-row entry "Minimum:" {:type :time} min-path put-fn])
         (when (number? story)
           [input-row entry "Maximum:" {:type :time} max-path put-fn])]))))

(defn criterion [{:keys [entry idx put-fn] :as params}]
  (let [path [:habit :criteria idx :type]
        habit-type (get-in entry path)
        rm-click (fn []
                   (let [rm #(let [criteria %]
                               (vec (concat (take idx criteria)
                                            (drop (inc idx) criteria))))
                         updated (update-in entry [:habit :criteria] rm)]
                     (put-fn [:entry/update-local updated])))]
    [:div.criterion
     [:i.fas.fa-trash-alt
      {:on-click rm-click}]
     (when-not habit-type
       [:div.row
        [:label "Habit Type:"]
        [uc/select {:on-change uc/select-update
                    :entry     entry
                    :put-fn    put-fn
                    :path      path
                    :xf        keyword
                    :options   {:min-max-sum   "min/max sum"
                                :min-max-time  "min/max time"
                                ;:checked-off   "checked off"
                                :questionnaire "questionnaire"}}]])
     (when (= :min-max-sum habit-type)
       [min-max-sum params])
     (when (= :min-max-time habit-type)
       [min-max-time params])
     (when (= :questionnaire habit-type)
       [quest-details params])]))

(defn habit-details [entry put-fn]
  (let [add-criterion (fn [entry]
                        (fn [_]
                          (let [updated (update-in entry [:habit :criteria] #(vec (conj % {})))]
                            (put-fn [:entry/update-local updated]))))
        gql-res (subscribe [:gql-res])
        ts (:timestamp entry)
        habits-successes (reaction (-> @gql-res :habits-success :data :habits_success))
        completions (reaction (->> @habits-successes
                                   (filter #(= ts (:timestamp (:habit_entry %))))
                                   first
                                   :completed
                                   reverse))]
    (fn [entry put-fn]
      (let [criteria (get-in entry [:habit :criteria])]
        [:div.habit-details
         [:h3.header "Habit details"]
         [:div.row
          [:label "Active? "]
          [uc/switch {:entry entry :put-fn put-fn :path [:habit :active]}]]
         [:div.row
          [:label "Schedule:"]
          [uc/select {:on-change uc/select-update
                      :entry     entry
                      :put-fn    put-fn
                      :path      [:habit :schedule]
                      :xf        keyword
                      :options   {:daily "per day"
                                  ;:weekly "per week"
                                  }}]]
         [:div.row
          [:h3 "Criteria"]
          [:div.add-criterion {:on-click (add-criterion entry)}
           [:i.fas.fa-plus]]]
         (for [[i c] (map-indexed (fn [i v] [i v]) criteria)]
           ^{:key i}
           [criterion {:entry  entry
                       :put-fn put-fn
                       :idx    i}])
         [:div.completion
          (for [completed @completions]
            [:span.status {:class (when completed "success")}])]]))))
