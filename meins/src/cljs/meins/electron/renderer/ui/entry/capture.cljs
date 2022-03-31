(ns meins.electron.renderer.ui.entry.capture
  (:require ["moment" :as moment]
            [clojure.set :as set]
            [clojure.string :as s]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.questionnaires :as q]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))

(defn parse-and-set [entry path tag input-type]
  (let [value (get-in entry path)]
    (when-not value
      (when (and (= input-type :number))
        (let [p1 (-> (:md entry) (s/split tag) first)
              last-n (last (re-seq #"[0-9]*\.?[0-9]+" p1))]
          (when last-n
            (let [updated (assoc-in entry path (js/parseFloat last-n))]
              (emit [:entry/update-local updated])))))
      (when (and (= input-type :time))
        (let [p1 (-> (:md entry) (s/split tag) first)
              v (last (re-seq #"\d+:\d{2}" p1))]
          (when v
            (let [m (.asMinutes (.duration moment v))
                  updated (assoc-in entry path m)]
              (emit [:entry/update-local updated]))))))))

(defn field-input [entry field tag k]
  (let [input-cfg (:cfg field)
        input-type (:type input-cfg)
        path [:custom_fields tag k]
        on-change-fn
        (fn [ev]
          (let [v (.. ev -target -value)
                parsed (case input-type
                         :number (when (seq v) (js/parseFloat v))
                         :time (when (seq v)
                                 (.asMinutes (.duration moment v)))
                         v)
                updated (assoc-in entry path parsed)]
            (emit [:entry/update-local updated])))
        input-cfg (merge
                    input-cfg
                    {:on-change on-change-fn
                     :class     (when (= input-type :time) "time")
                     :type      input-type})]
    (fn [entry field tag _k]
      (when-not (contains? (:custom_fields entry) "#BP")
        (parse-and-set entry path tag input-type))
      (let [value (get-in entry path)
            value (if (and value (= :time input-type))
                    (h/m-to-hh-mm value)
                    value)
            input-cfg (merge input-cfg
                             {:on-key-down (h/key-down-save entry)
                              :value       value})]
        [:tr
         [:td [:label (:label field)]]
         [:td
          (if (= input-type :switch)
            [uc/switch {:entry    entry
                        :msg-type :entry/update
                        :path     path}]
            [:input input-cfg])]]))))

(defn custom-fields-div
  "In edit mode, allow editing of custom fields, otherwise show a summary."
  [_entry _edit-mode?]
  (let [options (subscribe [:options])
        custom-fields (reaction (:custom-fields @options))]
    (fn custom-fields-render [entry edit-mode?]
      (when-let [custom-fields @custom-fields]
        (let [ts (:timestamp entry)
              tags (set/union (set (:tags entry)) (set (:perm_tags entry)))
              entry-field-tags (select-keys custom-fields tags)
              default-story (->> entry-field-tags
                                 (map (fn [[_k v]] (:default-story v)))
                                 (filter identity)
                                 first)]
          (when (and edit-mode? default-story (not (:primary_story entry)))
            (emit [:entry/update-local (merge entry
                                              {:primary_story  default-story
                                               :linked-stories #{default-story}})]))
          [:form.custom-fields
           (for [[tag conf] (sort-by first entry-field-tags)]
             ^{:key (str "cf" ts tag)}
             [:div
              [:table
               [:tbody
                (for [[k field] (:fields conf)]
                  ^{:key (str "cf" ts tag k)}
                  [field-input entry field tag k])]]])])))))

(defn questionnaire-div
  "In edit mode, allow editing of questionnaire, otherwise show a summary."
  [_entry _edit-mode?]
  (let [options (subscribe [:options])
        local (r/atom {:expanded false})
        questionnaires (reaction (:questionnaires @options))]
    (fn questionnaire-render [entry edit-mode?]
      (when-let [questionnaires @questionnaires]
        (let [ts (:timestamp entry)
              questionnaire-tags (:mapping questionnaires)
              tags (set/union (set (:tags entry)) (set (:perm_tags entry)))
              q-tags (select-keys questionnaire-tags tags)
              q-mapper (fn [[_t k]] [k (get-in questionnaires [:items k])])
              pomo-q [:pomo1 (get-in questionnaires [:items :pomo1])]
              entry-questionnaires (map q-mapper q-tags)
              completed-pomodoro (and (>= (:completed_time entry)
                                          (:planned_dur entry 1500))
                                      (= (:entry_type entry) :pomodoro)
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
                                           (emit [:entry/update-local updated])))]
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
