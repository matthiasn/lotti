(ns meins.jvm.ws
  (:require [taoensso.timbre :refer [info debug warn trace error]]
            [io.pedestal.http.jetty.websockets :as ws]
            [clojure.core.async :as async]
            [ring.util.response :as ring-resp]
            [io.pedestal.http.route.definition :refer [defroutes]]
            [io.pedestal.http.route :as route]
            [io.pedestal.http :as server]
            [io.pedestal.http :as http]
            [clojure.edn :as edn])
  (:import [org.eclipse.jetty.websocket.api Session]))

(defn deserialize-meta [payload]
  (let [[cmd-type {:keys [msg msg-meta]}] payload]
    (with-meta [cmd-type msg] msg-meta)))

(defn home-page [request]
  (ring-resp/response "Hello World!"))

(defroutes routes [[["/" {:get home-page}]]])

(def ws-clients (atom {}))

(defn new-ws-client [ws-session send-ch]
  (async/put! send-ch "This will be a text message")
  (swap! ws-clients assoc ws-session send-ch))

;; This is just for demo purposes
(defn send-and-close! []
  (let [[ws-session send-ch] (first @ws-clients)]
    (async/put! send-ch "A message from the server")
    ;; And now let's close it down...
    (async/close! send-ch)
    ;; And now clean up
    (swap! ws-clients dissoc ws-session)))

(defn send-message-to-all! [message]
  (doseq [[^Session session channel] @ws-clients]
    (when (.isOpen session)
      (async/put! channel message))))

(defn state-fn [put-fn]
  (let [state (atom {})
        port (dec (Integer/parseInt (get (System/getenv) "PORT" "8765")))
        on-connect (ws/start-ws-connection new-ws-client)
        on-text (fn [msg]
                  (let [parsed (edn/read-string msg)
                        msg (deserialize-meta parsed)]
                    (put-fn msg)
                    (info :msg (str "A client sent - " msg))))
        on-binary (fn [payload offset length]
                    (info :msg "Binary Message!" :bytes payload))
        on-error (fn [t] (error :msg "WS Error happened" :exception t))
        on-close (fn [num-code reason-text]
                   (info :msg "WS Closed:" :reason reason-text))
        ws-paths {"/ws" {:on-connect on-connect
                         :on-text    on-text
                         :on-binary  on-binary
                         :on-error   on-error
                         :on-close   on-close}}
        add-endpoints #(ws/add-ws-endpoints % ws-paths)]
    (-> {::http/routes            routes
         ::http/type              :jetty
         ::http/container-options {:context-configurator add-endpoints}
         ::http/host              "localhost"
         ::http/port              port
         :env                     :dev
         ::server/join?           false
         ;; all origins are allowed in dev mode
         ::server/allowed-origins {:creds           true
                                   :allowed-origins (constantly true)}}
        ;; Wire up interceptor chains
        server/default-interceptors
        server/dev-interceptors
        server/create-server
        server/start)
    (info "Websocket component listening on port" port)
    {:state state}))

(defn all-msgs-handler [{:keys [msg-type msg-meta msg-payload]}]
  (let [msg-w-ser-meta [msg-type {:msg msg-payload :msg-meta msg-meta}]]
    (send-message-to-all! (pr-str msg-w-ser-meta))
    {}))

(defn cmp-map [cmp-id cfg]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :opts        {:reload-cmp     false
                 :validate-in    false
                 :validate-out   false
                 :validate-state false}
   :handler-map (zipmap (:relay-types cfg) (repeat all-msgs-handler))})
