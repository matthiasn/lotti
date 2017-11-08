(ns meo.jvm.imports.screenshot
  (:require [clojure.pprint :as pp]
            [me.raynes.conch :refer [programs]]
            [clojure.tools.logging :as log]
            [meo.jvm.file-utils :as fu]))

(programs screencapture)
(programs scrot)

(defn import-screenshot [{:keys [put-fn msg-meta msg-payload]}]
  (let [filename (str fu/img-path (:filename msg-payload))
        os (System/getProperty "os.name")]
    (log/info "importing screenshot" filename)
    (when (= os "Mac OS X")
      (screencapture filename))
    (when (= os "Linux")
      (scrot filename)))
  {:emit-msg [:cmd/schedule-new
              {:timeout 3000 :message (with-meta [:search/refresh] msg-meta)}]})
