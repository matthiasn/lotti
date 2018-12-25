(ns meo.electron.renderer.ui.entry.pomodoro
  (:require [reagent.core :as r]
            [meo.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [moment]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [matthiasn.systems-toolbox.component :as st]))

(defn pomodoro-time [entry _edit-mode?]
  (let [local (r/atom {:edit false})
        time-click #(swap! local assoc-in [:edit] true)
        busy-status (subscribe [:busy-status])
        running-pomodoro (subscribe [:running-pomodoro])]
    (fn [entry edit-mode?]
      (let [completed-time (:completed_time entry 0)
            formatted (h/s-to-hh-mm-ss completed-time)
            on-change (fn [ev]
                        (let [v (.. ev -target -value)
                              parsed (when (seq v)
                                       (* 60 (.asMinutes (.duration moment v))))
                              updated (assoc-in entry [:completed_time] parsed)]
                          (emit [:entry/update-local updated])))
            running? (and (:pomodoro-running entry)
                          (= @running-pomodoro (:timestamp entry))
                          (< (- (st/now) (or (:last @busy-status) 0)) 2000))]
        [:div.pomodoro
         (if (and edit-mode? (:edit @local) (not running?))
           [:input {:value     (h/s-to-hh-mm completed-time)
                    :type      :time
                    :on-change on-change}]
           [:div.dur {:on-click time-click}
            formatted])]))))

(defn pomodoro-btn [entry _edit-mode?]
  (let [busy-status (subscribe [:busy-status])
        running-pomodoro (subscribe [:running-pomodoro])]
    (fn [entry edit-mode?]
      (let [running? (and (:pomodoro-running entry)
                          (= @running-pomodoro (:timestamp entry))
                          (< (- (st/now) (or (:last @busy-status) 0)) 2000))
            start-stop #(let [color (if running? :green :red)]
                          (emit [:blink/busy {:color color}])
                          (if running?
                            (emit [:cmd/pomodoro-stop entry])
                            (emit [:cmd/pomodoro-start entry])))]
        [:div.pomodoro
         (when edit-mode?
           [:span.btn.start-stop {:on-click start-stop
                                  :class    (if running? "stop" "start")}
            [:i.fas {:class (if running? "fa-pause-circle"
                                         "fa-play-circle")}]])]))))

(defn pomodoro-footer [entry]
  (let [logged-duration (subscribe [:logged-duration entry])]
    (fn [_entry]
      (when-let [duration @logged-duration]
        [:div.pomodoro
         [:div.dur duration]]))))
