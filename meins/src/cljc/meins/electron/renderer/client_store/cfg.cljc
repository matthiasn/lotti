(ns meins.electron.renderer.client-store.cfg
  (:require #?(:cljs [meins.electron.renderer.localstorage :as sa])
    #?(:clj [taoensso.timbre :refer [debug info]]
       :cljs [taoensso.timbre :refer [debug info]])
    [clojure.pprint :as pp]))

(def default-config
  {:active            nil
   :linked-filter     {}
   :show-context      true
   :show-maps-for     #{}
   :show-comments-for {}
   :show-pvt          true
   :mute              true
   :dashboard-banner  true
   :locale            :de
   :thumbnails        true
   :dashboard         {:active :general}
   :app-screenshot    false
   :lines-shortened   10})

#?(:clj  (defonce app-cfg (atom default-config))
   :cljs (defonce app-cfg (sa/local-storage (atom default-config)
                                            "meins_cfg")))

(defn save-cfg [{:keys [current-state]}]
  (reset! app-cfg (:cfg current-state))
  {})

(defn save-crypto [{:keys [current-state msg-payload]}]
  {:new-state (assoc current-state :crypto-cfg msg-payload)})

(defn toggle-key-fn [{:keys [current-state msg-payload]}]
  (let [{:keys [path reset-to]} msg-payload
        new-state (if reset-to
                    (assoc-in current-state path reset-to)
                    (update-in current-state path not))]
    {:new-state    new-state
     :send-to-self [:cfg/save]}))

(defn show-qr-code [{:keys []}]
  {:send-to-self [:cmd/toggle-key {:path [:cfg :qr-code] :reset-to true}]
   :emit-msg     [:schedule/new
                  {:timeout 20000
                   :message [:cmd/toggle-key {:path     [:cfg :qr-code]
                                              :reset-to false}]}]})

(defn set-currently-dragged [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:cfg :currently-dragged] msg-payload)]
    {:new-state new-state}))

(defn toggle-set-fn
  "Toggles for example the visibility of a map or the edit mode for an individual
  journal entry. Requires the key to exist on the application state as a set."
  [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)
        timestamp (:timestamp msg-payload)
        new-state (if (contains? (get-in current-state path) timestamp)
                    (update-in current-state path disj timestamp)
                    (update-in current-state path conj timestamp))]
    {:new-state    new-state
     :send-to-self [:cfg/save]}))

(defn cal-to-day [{:keys [current-state msg-payload]}]
  (let [day (:day msg-payload)
        new-state (assoc-in current-state [:cfg :cal-day] day)]
    {:new-state    new-state
     :send-to-self [:cfg/save]}))

(defn set-conj-fn
  "Like toggle-set-fn but only adds timestamp to set specified in path.
   Noop if already in there."
  [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)
        ts (:timestamp msg-payload)
        new-state (update-in current-state path conj ts)]
    {:new-state    new-state
     :send-to-self [:cfg/save]}))

(defn assoc-in-state [{:keys [current-state msg-payload]}]
  (let [path (:path msg-payload)
        value (:value msg-payload)
        new-state (assoc-in current-state path value)]
    {:new-state    new-state
     :send-to-self [:cfg/save]}))
