(ns meo.electron.renderer.client-store
  (:require #?(:cljs [reagent.core :refer [atom]])
    #?(:clj [taoensso.timbre :refer [info debug]]
       :cljs [taoensso.timbre :refer-macros [info debug]])
            [matthiasn.systems-toolbox.component :as st]
            [meo.electron.renderer.client-store-entry :as cse]
            [meo.electron.renderer.client-store-search :as s]
            [meo.electron.renderer.client-store-cfg :as c]
            [meo.common.utils.misc :as u]))

(defn new-state-fn [{:keys [current-state msg-payload msg-meta]}]
  (let [store-meta (:renderer/store-cmp msg-meta)
        {:keys [entries entries-map]} msg-payload
        new-state (-> current-state
                      (assoc-in [:results] entries)
                      (update-in [:entries-map] merge entries-map)
                      (assoc-in [:timing] {:query (:duration-ms msg-payload)
                                           :rtt   (- (:in-ts store-meta)
                                                     (:out-ts store-meta))
                                           :count (count entries-map)}))]
    {:new-state new-state}))

(defn stats-tags-fn [{:keys [current-state msg-payload put-fn]}]
  (let [stories (:stories msg-payload)
        sorted-stories (sort (fn [[_ x] [_ y]]
                               (< (:story-name x) (:story-name y)))
                             stories)
        sagas (:sagas msg-payload)
        sorted-sagas (sort (fn [[_ x] [_ y]]
                             (< (:saga-name x) (:saga-name y)))
                           sagas)
        new-state
        (-> current-state
            (assoc-in [:options :hashtags] (:hashtags msg-payload))
            (assoc-in [:options :pvt-hashtags] (:pvt-hashtags msg-payload))
            (assoc-in [:options :pvt-displayed] (:pvt-displayed msg-payload))
            (assoc-in [:options :custom-fields] (:custom-fields (:cfg msg-payload)))
            (assoc-in [:cfg :pid] (:pid (:cfg msg-payload)))
            (assoc-in [:options :questionnaires] (:questionnaires (:cfg msg-payload)))
            (assoc-in [:options :custom-field-charts] (:custom-field-charts (:cfg msg-payload)))
            (assoc-in [:options :stories] stories)
            (assoc-in [:backend-cfg] (:cfg msg-payload))
            (assoc-in [:options :locations] (:locations msg-payload))
            (assoc-in [:options :sorted-stories] sorted-stories)
            (assoc-in [:options :sagas] sagas)
            (assoc-in [:options :sorted-sagas] sorted-sagas)
            (assoc-in [:options :mentions] (:mentions msg-payload))
            (assoc-in [:cfg :briefing] (-> msg-payload :cfg :briefing)))]
    {:new-state new-state}))

(defn stats-tags-fn2 [{:keys [current-state msg-payload put-fn]}]
  (let [new-state (merge current-state msg-payload)]
    {:new-state new-state}))

(defn save-stats-fn2 [{:keys [current-state msg-payload put-fn]}]
  (let [new-state (update-in current-state [:stats] merge msg-payload)]
    {:new-state new-state}))

(defn initial-state-fn [put-fn]
  (let [cfg (assoc-in @c/app-cfg [:qr-code] false)
        state (atom {:entries          []
                     :startup-progress 0
                     :last-alive       (st/now)
                     :busy-color       :green
                     :new-entries      @cse/new-entries-ls
                     :query-cfg        @s/query-cfg
                     :pomodoro-stats   (sorted-map)
                     :task-stats       (sorted-map)
                     :wordcount-stats  (sorted-map)
                     :options          {:pvt-hashtags #{"#pvt"}}
                     :cfg              cfg})]
    (put-fn [:state/stats-tags-get])
    (put-fn [:stats/get2])
    (put-fn [:cfg/refresh])
    (put-fn [:state/search (u/search-from-cfg @state)])
    {:state state}))

(defn save-stats-fn [{:keys [current-state msg-payload]}]
  (let [k (case (:type msg-payload)
            :stats/pomodoro :pomodoro-stats
            :stats/tasks :task-stats
            :stats/wordcount :wordcount-stats
            :stats/custom-fields :custom-field-stats
            :stats/media :media-stats
            nil)
        day-stats (into (sorted-map) (:stats msg-payload))]
    (if k
      {:new-state (assoc-in current-state [k] day-stats)}
      (prn "WARN: No key defined for " msg-payload))))

(defn nav-handler [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:current-page] msg-payload)]
    {:new-state new-state}))

(defn blink-busy [{:keys [current-state msg-payload]}]
  (let [color (:color msg-payload)
        new-state (assoc-in current-state [:busy-status :color] color)]
    {:new-state new-state}))

(defn save-backend-cfg [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:backend-cfg] msg-payload)]
    {:new-state new-state}))

(defn progress [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:startup-progress] msg-payload)]
    {:new-state new-state}))

(defn ping [_]
  #?(:cljs (info :ping))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    initial-state-fn
   :state-spec  :state/client-store-spec
   :handler-map (merge cse/entry-handler-map
                       s/search-handler-map
                       {:state/new         new-state-fn
                        :stats/result      save-stats-fn
                        :stats/result2     save-stats-fn2
                        :state/stats-tags  stats-tags-fn
                        :state/stats-tags2 stats-tags-fn2
                        :cfg/save          c/save-cfg
                        :startup/progress  progress
                        :ws/ping           ping
                        :backend-cfg/new   save-backend-cfg
                        :nav/to            nav-handler
                        :blink/busy        blink-busy
                        :cfg/show-qr       c/show-qr-code
                        :cal/to-day        c/cal-to-day
                        :cmd/toggle        c/toggle-set-fn
                        :cmd/set-opt       c/set-conj-fn
                        :cmd/set-dragged   c/set-currently-dragged
                        :cmd/toggle-key    c/toggle-key-fn
                        :cmd/assoc-in      c/assoc-in-state})})
