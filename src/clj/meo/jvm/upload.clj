(ns meo.jvm.upload
  "Provides upload via REST call."
  (:require [ring.adapter.jetty :as j]
            [compojure.core :refer [routes POST PUT]]
            [clojure.java.io :as io]
            [meo.jvm.imports.entries :as ie]
            [meo.jvm.files :as f]
            [image-resizer.util :refer :all]
            [clojure.string :as s]
            [clojure.tools.logging :as log]
            [meo.jvm.file-utils :as fu])
  (:import (java.net ServerSocket)))

(def upload-port (atom nil))

(defn get-free-port []
  (let [socket (ServerSocket. 0)
        port (.getLocalPort socket)]
    (.close socket)
    port))

(defn start-server
  "Fires up REST endpoint that accepts import files:
    - /upload/text-entry.json
    - /upload/visits.json

   Then schedules shutdown."
  [{:keys [put-fn cmp-state current-state msg-meta]}]
  (when-let [server (:server current-state)]
    (log/info "Stopping Upload Server")
    (.stop server))
  (reset! upload-port (get-free-port))
  (log/info "Starting Upload Server on port" @upload-port)
  (let [post-fn (fn [filename req put-fn]
                  (with-open [rdr (io/reader (:body req))]
                    (case filename
                      "text-entries.json" (ie/import-text-entries-fn
                                            rdr put-fn {} filename)
                      "visits.json" (ie/import-visits-fn rdr put-fn {} filename)
                      (prn req))
                    "OK"))
        binary-post-fn (fn [dir filename req]
                         (let [filename (str fu/data-path "/" dir "/" filename)
                               file (java.io.File. filename)]
                           (io/make-parents file)
                           (log/info :server/upload-cmp req)
                           (io/copy (:body req) file))
                         "OK")
        app (routes
              (PUT "/upload/:dir/:file" [dir file :as r]
                (binary-post-fn dir file r))
              (POST "/upload/:filename" [filename :as r]
                (post-fn filename r put-fn)))
        server (j/run-jetty app {:port @upload-port :join? false})
        new-meta (assoc-in msg-meta [:sente-uid] :broadcast)]
    {:new-state (assoc-in current-state [:server] server)
     :emit-msg  [[:cmd/schedule-new
                  {:timeout 120000
                   :message [:import/stop-server]}]
                 (with-meta [:cfg/show-qr] new-meta)]}))

(defn stop-server
  [{:keys [current-state]}]
  (log/info "Stopping Upload Server")
  (.stop (:server current-state))
  {:new-state (assoc-in current-state [:server] nil)})

(defn cmp-map
  [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:import/listen      start-server
                 :import/stop-server stop-server}})

