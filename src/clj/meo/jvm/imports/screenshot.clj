(ns meo.jvm.imports.screenshot
  (:require [clojure.pprint :as pp]
            [clojure.java.shell :refer [sh]]
            [clojure.tools.logging :as log]
            [meo.jvm.file-utils :as fu]))

(defn import-screenshot [{:keys [put-fn msg-meta msg-payload]}]
  (let [filename (str fu/img-path (:filename msg-payload))
        os (System/getProperty "os.name")]
    (log/info "importing screenshot" filename)
    (when (= os "Mac OS X")
      (sh "/usr/sbin/screencapture" filename))
    (when (= os "Linux")
      (sh "/usr/bin/scrot" filename)))
  {:emit-msg [:cmd/schedule-new
              {:timeout 3000 :message (with-meta [:search/refresh] msg-meta)}]})
