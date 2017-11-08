(ns meo.electron.renderer.ui.pomodoro
  "This namespace holds the functions for rendering the text (markdown) content
   of a journal entry. This includes both a properly styled element for static
   content and the edit-mode view, with autosuggestions for tags and mentions."
  (:require [meo.common.utils.misc :as u]))

(defn pomodoro-defaults [ts]
  {:comment-for    ts
   :entry-type     :pomodoro
   :planned-dur    1500  ; 25 min
   :completed-time 0})

(defn pomodoro-stats [entries]
  (let [pomodoros (filter #(= :pomodoro (:entry-type %)) entries)
        completed (filter #(= (:planned-dur %) (:completed-time %)) pomodoros)]
    {:pomodoros           (count pomodoros)
     :completed-pomodoros (count completed)
     :total-time          (reduce + (map :completed-time pomodoros))}))
