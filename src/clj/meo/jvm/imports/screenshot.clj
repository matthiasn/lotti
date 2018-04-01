(ns meo.jvm.imports.screenshot
  (:require [clojure.pprint :as pp]
            [me.raynes.conch :refer [programs let-programs]]
            [taoensso.timbre :refer [info]]
            [meo.jvm.file-utils :as fu]
            [clojure.java.io :as io]
            [meo.jvm.utils.images :as img]))

(programs scrot)

(defn import-screenshot [{:keys [msg-meta msg-payload]}]
  (let [filename (str fu/img-path (:filename msg-payload))
        os (System/getProperty "os.name")]
    (info "importing screenshot" filename)
    (when (= os "Mac OS X")
      (let-programs [screencapture "/usr/sbin/screencapture"]
                    (screencapture filename)))
    (when (= os "Linux")
      (scrot filename))
    (let [file (io/file filename)]
      (img/gen-thumbs file)))
  {:emit-msg [:cmd/schedule-new
              {:timeout 3000 :message (with-meta [:search/refresh] msg-meta)}]})
