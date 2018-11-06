(ns meo.electron.renderer.ui.entry.pomodoro
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [moment]
            [taoensso.timbre :refer-macros [info debug]]
            [reagent.ratom :refer-macros [reaction]]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.ui.entry.utils :as eu]
            [matthiasn.systems-toolbox.component :as st]))

(defn pomodoro-action [entry _edit-mode? put-fn]
  (let [local (r/atom {:edit false})
        time-click #(swap! local assoc-in [:edit] true)
        busy-status (subscribe [:busy-status])
        running-pomodoro (subscribe [:running-pomodoro])]
    (fn [entry edit-mode? _put-fn]
      (let [completed-time (:completed_time entry 0)
            formatted (h/s-to-hh-mm-ss completed-time)
            on-change (fn [ev]
                        (let [v (.. ev -target -value)
                              parsed (when (seq v)
                                       (* 60 (.asMinutes (.duration moment v))))
                              updated (assoc-in entry [:completed_time] parsed)]
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
            formatted])]))))

(defn pomodoro-footer [entry put-fn]
  (let [new-entries (subscribe [:new-entries])]
    (fn [entry _put-fn]
      (let [logged-duration (eu/logged-total new-entries entry)
            logged-duration (when (pos? logged-duration)
                              (h/s-to-hh-mm-ss logged-duration))]
        (when logged-duration
          [:div.pomodoro
           [:span.dur logged-duration]])))))
