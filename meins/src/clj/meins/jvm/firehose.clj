(ns meins.jvm.firehose
  (:require [taoensso.timbre :refer [info]]))

(def filename (if-let [log-dir (get (System/getenv) "LOG_DIR")]
                (str log-dir "meins-firehose.fh")
                "./log/meins-firehose.fh"))

(defn append-firehose-ev [{:keys [current-state msg-type msg-meta msg-payload]}]
  (when (:started current-state)
    (let [serializable {:msg-type    msg-type
                        :msg-meta    msg-meta
                        :msg-payload msg-payload}
          serialized (str (pr-str serializable) "\n")]
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