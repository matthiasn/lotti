(ns meins.electron.renderer.client-store.initial
  (:require #?(:cljs [reagent.core :refer [atom]])
            #?(:clj  [taoensso.timbre :refer [info debug]]
               :cljs [taoensso.timbre :refer-macros [info debug]])
            [meins.electron.renderer.client-store.entry :as cse]
            [meins.electron.renderer.client-store.search :as s]
            #?(:clj  [meins.jvm.datetime :as h]
               :cljs [meins.electron.renderer.helpers :as h])
            [meins.electron.renderer.client-store.cfg :as c]
            [matthiasn.systems-toolbox.component :as stc]))

(defn initial-queries [{:keys [current-state put-fn] :as m}]
  (info "performing initial queries")
  (let [run-query (fn [file id prio args]
                    (put-fn [:gql/query {:file     file
                                         :id       id
                                         :res-hash nil
                                         :prio     prio
                                         :args     args}]))
        ymd (or (get-in current-state [:cfg :cal-day]) (h/ymd (stc/now)))
        pvt (-> current-state :cfg :show-pvt)]
    (put-fn [:cfg/refresh])
    (put-fn [:crypto/get-cfg])
    (run-query "briefing.gql" :briefing 12 [ymd pvt])
    (run-query "logged-by-day.gql" :logged-by-day 13 [ymd])
    (put-fn [:gql/query {:file "habits-success.gql"
                         :id   :habits-success
                         :prio 13
                         :args [30 pvt]}])
    (run-query "started-tasks.gql" :started-tasks 14 [pvt])
    (run-query "bp.gql" :bp 14 [365])
    ;(run-query "award-points.gql" :award-points 14 [])
    (run-query "open-tasks.gql" :open-tasks 14 [pvt])
    (run-query "options.gql" :options 10 nil)
    (run-query "day-stats.gql" :day-stats 15 [180])
    (s/gql-query :left current-state true put-fn)
    (s/gql-query :right current-state true put-fn)
    (s/dashboard-cfg-query current-state put-fn)
    (run-query "count-stats.gql" :count-stats 20 nil)
    (put-fn [:startup/progress?])
    (put-fn [:update/auto-check])
    {}))
