(ns meo.jvm.firehose
  (:require [taoensso.timbre :refer [info]]
            [clj-time.core :as time]
            [clj-time.format :as tf]))

(def filename (if (get (System/getenv) "PORT")
                "/tmp/meo-"
                "/tmp/meo-dev-"))

(defn append-firehose-ev [{:keys [current-state msg-type msg-meta msg-payload]}]
  (when (:started current-state)
    (let [serializable {:msg-type    msg-type
                        :msg-meta    msg-meta
                        :msg-payload msg-payload}
          serialized (str (pr-str serializable) "\n")
          ymd (tf/unparse (tf/formatters :year-month-day) (time/now))
          filename (str filename ymd ".fh")]
      (spit filename serialized :append true)))
  {})

(defn start-stop [{:keys [current-state msg-payload]}]
  (if (= (:cmd msg-payload) :start)
    (info "firehose started")
    (info "firehose stopped"))
  {:new-state (assoc-in current-state [:started] (= (:cmd msg-payload) :start))})

(defn firehose-cmp [id]
  {:cmp-id      id
   :opts        {:in-chan  [:buffer 100]
                 :out-chan [:buffer 100]}
   :handler-map {:firehose/cmp-put           append-firehose-ev
                 :firehose/cmp-publish-state append-firehose-ev
                 :firehose/cmp-recv          append-firehose-ev
                 :firehose/cmd               start-stop}})