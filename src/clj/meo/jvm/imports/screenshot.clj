(ns meo.jvm.imports.screenshot
  (:require [me.raynes.conch :refer [programs let-programs]]
            [taoensso.timbre :refer [info]]
            [meo.jvm.file-utils :as fu]
            [clojure.java.io :as io]
            [meo.jvm.utils.images :as img]))

(programs scrot)

(defn import-screenshot [{:keys [msg-payload]}]
  (let [filename (str fu/img-path (:filename msg-payload))
        os (System/getProperty "os.name")]
    (info "importing screenshot" filename)
    (when (= os "Mac OS X")
      (let-programs [screencapture "/usr/sbin/screencapture"]
                    (screencapture filename)))
    (when (= os "Linux")
      (scrot filename))
    (img/gen-thumbs (io/file filename)))
  {})
