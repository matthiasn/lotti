(ns meins.electron.renderer.ui.pomodoro
  "This namespace holds the functions for rendering the text (markdown) content
   of a journal entry. This includes both a properly styled element for static
   content and the edit-mode view, with autosuggestions for tags and mentions.")

(defn pomodoro-defaults [ts]
  {:comment_for    ts
   :entry_type     :pomodoro
   :planned_dur    1500  ; 25 min
   :completed_time 0})

(defn pomodoro-stats [entries]
  (let [pomodoros (filter #(= :pomodoro (:entry_type %)) entries)
        completed (filter #(= (:planned_dur %) (:completed_time %)) pomodoros)]
    {:pomodoros           (count pomodoros)
     :completed_pomodoros (count completed)
     :total_time          (reduce + (map :completed_time pomodoros))}))
