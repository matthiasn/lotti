(ns meo.ios.sync)

(def credentials
  {:server    "https://foo.com/"
   :username  "mn"
   :password  ""
   :directory "/meo/"})

(def secret "some shared secret")

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))

(def webdav-fs (js/require "webdav-fs"))

(def buffer (js/require "buffer"))
(def buffer2 (aget buffer "Buffer"))

(defn write-to-webdav [node-id entry put-fn]
  (put-fn [:log/info (str "buffer: " (js->clj buffer))])
  (put-fn [:log/info (str "buffer2: " (js->clj buffer2))])
  (aset js/window "Buffer" buffer2)
  (try
    (let [data (pr-str entry)
          ciphertext (.toString (.encrypt aes data secret))
          {:keys [server username password]} credentials
          client (webdav-fs. server username password)
          dir (str "/meo/" node-id)
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
