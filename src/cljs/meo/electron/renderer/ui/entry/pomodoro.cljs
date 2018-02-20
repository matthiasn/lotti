(ns meo.electron.renderer.ui.entry.pomodoro
  (:require [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [moment]
            [meo.electron.renderer.helpers :as h]
            [matthiasn.systems-toolbox.component :as st]))

(defn pomodoro-header [entry edit-mode? put-fn]
  (let [local (r/atom {:edit false})
        click #(swap! local assoc-in [:edit] true)
        planning-mode (subscribe [:planning-mode])
        logged-time (subscribe [:entry-logged-time (:timestamp @entry)])
        busy-status (subscribe [:busy-status])
        running-pomodoro (subscribe [:running-pomodoro])
        on-change (fn [ev]
                    (let [v (.. ev -target -value)
                          parsed (when (seq v)
                                   (* 60 (.asMinutes (.duration moment v))))
                          updated (assoc-in @entry [:completed-time] parsed)]
                      (put-fn [:entry/update-local updated])))]
    (fn [entry edit-mode? put-fn]
      (when-not edit-mode? (swap! local assoc-in [:edit] false))
      (let [since-last-busy (- (st/now) (or (:last @busy-status) 0))
            running? (and (:pomodoro-running @entry)
                          (= @running-pomodoro (:timestamp @entry))
                          (< since-last-busy 2000))
            completed-time (:completed-time @entry 0)
            start-stop #(let [color (if running? :green :red)]
                          (put-fn [:blink/busy {:color color}])
                          (if running?
                            (put-fn [:cmd/pomodoro-stop @entry])
                            (put-fn [:cmd/pomodoro-start @entry])))
            formatted (h/s-to-hh-mm-ss completed-time)
            logged-duration (when-let [t @logged-time]
                              (when (pos? t)
                                (h/s-to-hh-mm-ss t)))]
        (if (and (= (:entry-type @entry) :pomodoro) @planning-mode)
          [:div.pomodoro
           (when edit-mode?
             [:span.btn.start-stop
              {:on-click start-stop
               :class    (if running? "stop" "start")}
              [:i.fas {:class (if running? "fa-pause-circle"
                                           "fa-play-circle")}]])
           (if (and edit-mode? (:edit @local) (not running?))
             [:input {:value     (h/s-to-hh-mm completed-time)
                      :type      :time
                      :on-change on-change}]
             [:span.dur {:on-click click}
              formatted])]
          (when logged-duration
            [:div.pomodoro
             [:span.dur logged-duration]]))))))
