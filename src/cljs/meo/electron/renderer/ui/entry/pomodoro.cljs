(ns meo.electron.renderer.ui.entry.pomodoro
  (:require [meo.common.utils.misc :as u]
            [reagent.core :as r]
            [re-frame.core :refer [subscribe]]
            [moment]
            [meo.electron.renderer.helpers :as h]))

(defn pomodoro-header [entry edit-mode? put-fn]
  (let [local (r/atom {:edit false})
        click #(swap! local assoc-in [:edit] true)
        planning-mode (subscribe [:planning-mode])
        on-change (fn [ev]
                    (let [v (.. ev -target -value)
                          parsed (when (seq v)
                                   (* 60 (.asMinutes (.duration moment v))))
                          updated (assoc-in @entry [:completed-time] parsed)]
                      (put-fn [:entry/update-local updated])))]
    (fn [entry edit-mode? put-fn]
      (when-not edit-mode? (swap! local assoc-in [:edit] false))
      (let [running? (:pomodoro-running @entry)
            completed-time (:completed-time @entry)
            start-stop #(let [color (if running? :green :red)]
                          (put-fn [:blink/busy {:color color}])
                          (put-fn [:cmd/pomodoro-start @entry]))]
        (when (and (= (:entry-type @entry) :pomodoro) @planning-mode)
          [:div.pomodoro
           [:span.fa.fa-clock-o.completed]
           (when (pos? completed-time)
             (if (and edit-mode? (:edit @local) (not running?))
               [:input {:value     (h/s-to-hh-mm completed-time)
                        :type      :time
                        :on-change on-change}]
               [:span.dur {:on-click click}
                (u/duration-string completed-time)]))
           (when edit-mode?
             [:span.btn {:on-click start-stop
                         :class    (if running? "stop" "start")}
              [:span.fa
               {:class (if running? "fa-pause-circle-o" "fa-play-circle-o")}]
              (if running? "pause" "start")])])))))