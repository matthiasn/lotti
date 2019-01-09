(ns ^:figwheel-always meins.dev
  (:require [meins.electron.renderer.core :as c]
            [taoensso.timbre :refer [info]]
            [figwheel.client :as figwheel :include-macros true]))

(enable-console-print!)

(defn jscb []
  (c/init))

(figwheel/watch-and-reload
  :websocket-url "ws://localhost:3459/figwheel-ws"
  :jsload-callback jscb)

(c/init)
