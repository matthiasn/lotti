(ns meins.electron.main.helpers
  (:require ["moment" :as moment]))

(defn format-time [m] (.format (moment m) "YYYY-MM-DD HH:mm"))
