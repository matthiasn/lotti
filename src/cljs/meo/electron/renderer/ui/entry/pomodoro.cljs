(ns meo.electron.renderer.ui.entry.pomodoro
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [moment]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [matthiasn.systems-toolbox.component :as st]))

(defn pomodoro-header [entry _edit-mode? put-fn]
  (let [local (r/atom {:edit false})
        time-click #(swap! local assoc-in [:edit] true)
        planning-mode (subscribe [:planning-mode])
        logged-time (subscribe [:entry-logged-time (:timestamp entry)])
        busy-status (subscribe [:busy-status])
        running-pomodoro (subscribe [:running-pomodoro])]
    (fn [entry edit-mode? _put-fn]
      (let [completed-time (:completed-time entry 0)
            formatted (h/s-to-hh-mm-ss completed-time)
            logged-duration (when-let [t @logged-time]
                              (when (pos? t)
                                (h/s-to-hh-mm-ss t)))
            on-change (fn [ev]
                        (let [v (.. ev -target -value)
                              parsed (when (seq v)
                                       (* 60 (.asMinutes (.duration moment v))))
                              updated (assoc-in entry [:completed-time] parsed)]
                          (put-fn [:entry/update-local updated])))
            running? (and (:pomodoro-running entry)
                          (= @running-pomodoro (:timestamp entry))
                          (< (- (st/now) (or (:last @busy-status) 0)) 2000))
            start-stop #(let [color (if running? :green :red)]
                          (put-fn [:blink/busy {:color color}])
                          (if running?
                            (put-fn [:cmd/pomodoro-stop entry])
                            (put-fn [:cmd/pomodoro-start entry])))]
        (when-not edit-mode? (swap! local assoc-in [:edit] false))
        (if (and (= (:entry-type entry) :pomodoro) @planning-mode)
          [:div.pomodoro
           (when edit-mode?
             [:span.btn.start-stop {:on-click start-stop
                                    :class    (if running? "stop" "start")}
              [:i.fas {:class (if running? "fa-pause-circle"
                                           "fa-play-circle")}]])
           (if (and edit-mode? (:edit @local) (not running?))
             [:input {:value     (h/s-to-hh-mm completed-time)
                      :type      :time
                      :on-change on-change}]
             [:span.dur {:on-click time-click}
              formatted])]
          (when logged-duration
            [:div.pomodoro
             [:span.dur logged-duration]]))))))
