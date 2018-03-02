(ns meo.ios.sync)

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))
(def webdav-fs (js/require "webdav-fs"))
(def buffer (aget (js/require "buffer") "Buffer"))
(aset js/window "Buffer" buffer)

(defn write-to-webdav [node-id secrets entry put-fn]
  (try
    (let [_ (put-fn [:log/info (str secrets)])
          data (pr-str entry)
          {:keys [server username password aes-secret]} secrets
          ciphertext (.toString (.encrypt aes data aes-secret))
          client (webdav-fs. server username password)
          ;dir (str "/meo/" node-id)
          dir (str "/meo/inbox")
          filename (str dir "/" (:timestamp entry) ".edn")
          mk-dir (aget client "mkdir")
          write (aget client "writeFile")
          write-err (fn [err]
                      (if err
                        (put-fn [:log/error
                                 (str "error writing " filename " on " server " " err)])
                        (put-fn [:log/info (str "wrote " filename)])))
          mkdir-err (fn [err]
                      (if err
                        (put-fn [:log/warn (str "could not create " dir err)])
                        (put-fn [:log/info (str "created " dir)])))]
      (put-fn [:log/info (str "webdav-fs: " webdav-fs)])
      (put-fn [:log/info (str "client: " (js->clj client))])
      (put-fn [:log/info (str "write: " write)])
      (put-fn [:log/info (str "mk-dir: " mk-dir)])
      (mk-dir dir mkdir-err)
      (write filename ciphertext write-err))
    (catch js/Object e (put-fn [:log/error (str e)]))))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:sync/upload write-to-webdav}})
