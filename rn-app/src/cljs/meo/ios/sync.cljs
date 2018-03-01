(ns meo.ios.sync)


(def webdav (js/require "webdav"))

(defn hello-world [node-id content put-fn]
  (try
    (let [{:keys [server username password]} credentials
          client (webdav. server username password)
          dir (str "/meo/" node-id "/")
          filename (str dir "helloworld.txt")]
      (-> (.createDirectory client dir)
          (.then #(put-fn [:log/info (str "created" dir)]))
          (.catch #(put-fn [:log/warn (str "could not create" dir %)])))
      (-> (.putFileContents client filename content (clj->js {:format "text"}))
          (.then #(put-fn [:log/info (str "copied" filename "to" server)]))
          (.catch #(put-fn [:log/error (str "could not copy" filename "to" server %)]))))
    (catch js/Object e (put-fn [:log/error (str e)]))))


(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:sync/upload hello-world}})
