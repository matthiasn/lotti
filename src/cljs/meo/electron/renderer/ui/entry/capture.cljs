(ns meo.electron.renderer.ui.entry.capture
  (:require [clojure.string :as s]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.ui.questionnaires :as q]
            [meo.electron.renderer.helpers :as h]
            [moment]
            [reagent.ratom :refer-macros [reaction]]
            [matthiasn.systems-toolbox.component :as st]
            [reagent.core :as r]))

(defn for-day
  [entry edit-mode? put-fn]
  (when (and (contains? (:tags entry) "#for-day")
             (not (= (:entry-type entry) :pomodoro)))
    (let [input-fn (fn [entry]
                     (fn [ev]
                       (let [day (h/target-val ev)
                             updated (assoc-in entry [:for-day] day)]
                         (put-fn [:entry/update-local updated]))))
          for-day (:for-day entry)]
      (when-not for-day
        (put-fn [:entry/update-local
                 (assoc-in entry [:for-day] (h/format-time (st/now)))]))
      [:fieldset
       [:legend "#for-day"]
       (if edit-mode?
         [:div [:label "Day: "]
          [:input {:type      :datetime-local
                   :on-change (input-fn entry)
                   :value     for-day}]]
         [:div for-day])])))

(defn custom-fields-div
  "In edit mode, allow editing of custom fields, otherwise show a summary."
  [entry put-fn edit-mode?]
  (let [options (subscribe [:options])
        custom-fields (reaction (:custom-fields @options))]
    (fn custom-fields-render [entry put-fn edit-mode?]
      (when-let [custom-fields @custom-fields]
        (let [ts (:timestamp entry)
              entry-field-tags (select-keys custom-fields (:tags entry))
              default-story (->> entry-field-tags
                                 (map (fn [[k v]] (:default-story v)))
                                 (filter identity)
                                 first)]
          (when (and edit-mode? default-story (not (:primary-story entry)))
            (put-fn [:entry/update-local (merge entry
                                                {:primary-story  default-story
                                                 :linked-stories #{default-story}})]))
          [:form.custom-fields
           [for-day entry edit-mode? put-fn]
           (for [[tag conf] entry-field-tags]
             ^{:key (str "cf" ts tag)}
             [:fieldset
              [:legend tag]
              (for [[k field] (:fields conf)]
                (let [input-cfg (:cfg field)
                      input-type (:type input-cfg)
                      path [:custom-fields tag k]
                      value (get-in entry path)
                      value (if (and value (= :time input-type))
                              (h/m-to-hh-mm value)
                              value)
                      on-change-fn
                      (fn [ev]
                        (let [v (.. ev -target -value)
                              parsed (case input-type
                                       :number (when (seq v) (js/parseFloat v))
                                       :time (when (seq v)
                                               (.asMinutes (.duration moment v)))
                                       v)
                              updated (assoc-in entry path parsed)]
                          (put-fn [:entry/update-local updated])))]
                  (when-not value
                    (when (and (= input-type :number) edit-mode?)
                      (let [p1 (-> (:md entry) (s/split tag) first)
                            last-n (last (re-seq #"[0-9]*\.?[0-9]+" p1))]
                        (when last-n
                          (let [updated (assoc-in entry path (js/parseFloat last-n))]
                            (put-fn [:entry/update-local updated])))))
                    (when (and (= input-type :time) edit-mode?)
                      (let [p1 (-> (:md entry) (s/split tag) first)
                            v (last (re-seq #"\d+:\d{2}" p1))]
                        (when v
                          (let [m (.asMinutes (.duration moment v))
                                updated (assoc-in entry path m)]
                            (put-fn [:entry/update-local updated]))))))
                  ^{:key (str "cf" ts tag k)}
                  [:div
                   [:label (:label field) ":"]
                   [:input (merge
                             input-cfg
                             {:on-change on-change-fn
                              :value     value})]]))])])))))

(defn questionnaire-div
  "In edit mode, allow editing of questionnaire, otherwise show a summary."
  [entry put-fn edit-mode?]
  (let [options (subscribe [:options])
        local (r/atom {:expanded false})
        questionnaires (reaction (:questionnaires @options))]
    (fn questionnaire-render [entry put-fn edit-mode?]
      (when-let [questionnaires @questionnaires]
        (let [ts (:timestamp entry)
              questionnaire-tags (:mapping questionnaires)
              q-tags (select-keys questionnaire-tags (:tags entry))
              q-mapper (fn [[t k]] [k (get-in questionnaires [:items k])])
              pomo-q [:pomo1 (get-in questionnaires [:items :pomo1])]
              entry-questionnaires (map q-mapper q-tags)
              completed-pomodoro (and (>= (:completed-time entry)
                                          (:planned-dur entry))
                                      (= (:entry-type entry) :pomodoro)
                                      (> ts 1505770346000))
              entry-questionnaires (into {} (if completed-pomodoro
                                              (conj entry-questionnaires pomo-q)
                                              entry-questionnaires))
              expanded (or edit-mode? (:expanded @local))
              expand-toggle #(swap! local update-in [:expanded] not)]
          [:div
           (for [[k conf] entry-questionnaires]
             (let [q-path [:questionnaires k]
                   scores (q/scores entry q-path conf)
                   reference (:reference conf)]
               ^{:key (str "cf" ts k)}
               [:form.questionnaire
                [:h3 (:header conf)
                 (when-not edit-mode?
                   [:span.fa.expand-toggle
                    {:on-click expand-toggle
                     :class    (if expanded "fa-compress" "fa-expand")}])]
                (when expanded
                  (:desc conf))
                (when expanded
                  [:ol
                   (for [{:keys [type path label one-line]} (:fields conf)]
                     (let [path (concat q-path path)
                           value (get-in entry path)
                           items (get-in questionnaires [:types type :items])]
                       ^{:key (str "q" ts k path)}
                       [:li
                        [:label {:class (str (when-not value "missing ")
                                             (when-not one-line "multi-line"))}
                         [:strong label]]
                        (when-not one-line [:br])
                        [:span.range
                         (for [item items]
                           (let [v (:value item)
                                 item-label (or (:label item) v)
                                 click (fn [_ev]
                                         (let [new-val (when-not (= value v) v)
                                               updated (assoc-in entry path new-val)]
                                           (put-fn [:entry/update-local updated])))]
                             ^{:key (str "q" ts k path v)}
                             [:span.opt.tooltip
                              {:on-click click
                               :class    (when (= value v) "sel")} item-label]))]]))])
                [:div.agg
                 (for [[k res] scores]
                   ^{:key k}
                   [:div
                    [:span (:label res)]
                    [:span.res (.toFixed (:score res) 2)]])]
                (when expanded
                  (if (string? reference)
                    [:cite reference]
                    reference))]))])))))
