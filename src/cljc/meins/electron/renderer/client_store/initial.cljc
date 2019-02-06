(ns meins.electron.renderer.client-store.initial
  (:require #?(:cljs [reagent.core :refer [atom]])
            #?(:clj  [taoensso.timbre :refer [info debug]]
               :cljs [taoensso.timbre :refer-macros [info debug]])
            [matthiasn.systems-toolbox.component :as st]
            [meins.electron.renderer.client-store.entry :as cse]
            [meins.electron.renderer.client-store.search :as s]
            [meins.electron.renderer.client-store.cfg :as c]))

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
                     :dashboard-data   (sorted-map)
                     :gql-res2         {:left  {:res (sorted-map-by >)}
                                        :right {:res (sorted-map-by >)}}
                     :options          {:pvt-hashtags #{"#pvt"}}
                     :cfg              cfg})]
    (put-fn [:imap/get-cfg])
    {:state state}))

(defn initial-queries [{:keys [current-state put-fn] :as m}]
  (info "performing initial queries")
  (let [run-query (fn [file id prio args]
                    (put-fn [:gql/query {:file     file
                                         :id       id
                                         :res-hash nil
                                         :prio     prio
                                         :args     args}]))
        pvt (-> current-state :cfg :show-pvt)]
    (put-fn [:cfg/refresh])
    (put-fn [:help/get-manual])
    (when-let [ymd (get-in current-state [:cfg :cal-day])]
      (run-query "briefing.gql" :briefing 12 [ymd pvt])
      (run-query "logged-by-day.gql" :logged-by-day 13 [ymd]))
    (put-fn [:gql/query {:file "habits-success.gql"
                         :id   :habits-success
                         :prio 13
                         :args [30 pvt]}])
    (run-query "started-tasks.gql" :started-tasks 14 [pvt false])
    (run-query "bp.gql" :bp 14 [365])
    ;(run-query "award-points.gql" :award-points 14 [])
    (run-query "open-tasks.gql" :open-tasks 14 [pvt])
    (run-query "options.gql" :options 10 nil)
    (run-query "day-stats.gql" :day-stats 15 [180])
    (s/gql-query :left current-state false put-fn)
    (s/gql-query :right current-state false put-fn)
    (s/dashboard-cfg-query current-state put-fn)
    (run-query "count-stats.gql" :count-stats 20 nil)
    (put-fn [:startup/progress?])
    (put-fn [:update/auto-check])
    {}))
