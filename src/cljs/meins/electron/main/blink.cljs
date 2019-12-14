(ns meins.electron.main.blink
  "Component for interacting with the awesome blink1 USB RGB LED notification
   light: https://blink1.thingm.com. Here, this little device is used to
   display if I should be busy or not."
  (:require ["moment" :as moment]
            [child_process :refer [spawn]]
            [fs :refer [existsSync]]
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.main.runtime :as rt]
            [taoensso.timbre :as timbre :refer [debug]]))

(def colors
  {:red    {:day "--hsb=10,255,255" :night "--hsb=10,255,100"}
   :orange {:day "--hsb=33,150,150" :night "--hsb=33,255,100"}
   :green  {:day "--hsb=65,255,255" :night "--hsb=65,255,100"}})

(defn spawn-process [cmd args opts]
  (debug "BLINK: spawning" cmd args opts)
  (spawn cmd (clj->js args) (clj->js opts)))

(defn blink
  "Calls the blink1 command line tool, which can for example be installed via
   homebrew with 'brew install blink1'. Does nothing when the binary doesn't
   exist."
  [args]
  (let [blink-path (:blink rt/runtime-info)]
    (if (existsSync blink-path)
      (spawn-process blink-path [args] []))))

(defn day-night? []
  (let [h (.hour (moment))]
    (if (or (< h 8) (> h 18)) :night :day)))

(defn state-fn [put-fn]
  (let [state (atom {:last-busy 0})
        k (day-night?)]
    (blink (k (:green colors)))
    {:state state}))

(defn blink-busy
  "Set light to red when busy and save last busy timestamp."
  [{:keys [current-state msg-payload]}]
  (let [ts (st/now)
        k (day-night?)
        color (:color msg-payload)
        arg (get-in colors [color k])]
    (debug "blink" arg)
    (blink arg)
    {:new-state (assoc-in current-state [:last-busy] ts)}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:blink/busy blink-busy}})
