(ns meins.electron.renderer.ui.preferences.assistants.custom-fields
  (:require [meins.electron.renderer.helpers :as h]
            [reagent.core :as r]
            [taoensso.timbre :refer [error info]]))

(def custom-field-definitions
  [{:tag    "#BP"
    :active true
    :items  [{:name  "bp_systolic"
              :label "BP systolic/mmHg"
              :type  :number
              :agg   :max
              :step  1}
             {:name  "bp_diastolic"
              :label "BP diastolic/mmHg"
              :type  :number
              :agg   :max
              :step  1}
             {:name  "heart_rate"
              :label "Heart rate"
              :type  :number
              :agg   :max
              :step  1}]}
   {:tag    "#steps"
    :active true
    :items  [{:name  "cnt"
              :label "Steps"
              :type  :number
              :agg   :max
              :step  1}]}
   {:tag    "#coffee"
    :active true
    :items  [{:name  "vol"
              :label "Coffee/ml"
              :type  :number
              :agg   :sum
              :step  1}]}
   {:tag    "#beer"
    :active true
    :items  [{:name  "vol"
              :label "Beer/ml"
              :type  :number
              :agg   :sum
              :step  1}]}
   {:tag    "#sleep"
    :active true
    :items  [{:name  "duration"
              :label "Sleep:"
              :type  :time
              :agg   :sum}]}
   {:tag    "#workout"
    :active true
    :items  [{:name  "duration"
              :label "Workout:"
              :type  :time
              :agg   :sum}]}
   {:tag    "#driving"
    :active true
    :items  [{:name  "duration"
              :label "Driving:"
              :type  :time
              :agg   :sum}]}
   {:tag    "#running"
    :active true
    :items  [{:name  "distance"
              :label "Distance/km:"
              :type  :number
              :agg   :sum
              :step  0.1}
             {:name  "duration"
              :type  :time
              :label "Duration:"
              :agg   :sum}
             {:name  "calories"
              :label "Calories:"
              :type  :number
              :agg   :sum
              :step  1}
             {:name  "sprints"
              :type  :number
              :label "Sprints:"
              :agg   :sum
              :step  1}
             {:name  "elevation-gain"
              :label "Elevation gain:"
              :type  :number
              :agg   :sum
              :step  1}]}
   {:tag    "#floss"
    :active true
    :items  [{:name  "completion"
              :label "Flossed?"
              :type  :switch}]}
   ])

(defn assistant [items]
  (let [existing (set (map first items))
        remaining (filter #(not (existing (:tag %))) custom-field-definitions)]
    (when (seq remaining)
      [:div.assistant
       [:h2 "Create commonly used fields with one click."]
       (for [cfd remaining]
         (let [tag (:tag cfd)
               click (h/new-entry {:entry_type       :custom-field-cfg
                                   :perm_tags        #{"#custom-field-cfg"}
                                   :tags             #{"#custom-field-cfg"}
                                   :custom_field_cfg cfd})]
           ^{:key tag}
           [:span.tag {:on-click click}
            tag]))])))
