(ns meo.ios.sync)

(def crypto-js (js/require "crypto-js"))
(def aes (aget crypto-js "AES"))
(def webdav-fs (js/require "webdav-fs"))
(def buffer (aget (js/require "buffer") "Buffer"))
(aset js/window "Buffer" buffer)

(defn write-to-webdav [secrets entry put-fn]
  (try
    (let [{:keys [server username password aes-secret directory]} secrets
          data (pr-str entry)
          ciphertext (.toString (.encrypt aes data aes-secret))
          client (webdav-fs. server username password)
          dir (str directory "/inbox")
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
      (mk-dir dir mkdir-err)
      (write filename ciphertext write-err)
      (put-fn [:log/info (str "written: " filename)]))
    (catch js/Object e (put-fn [:log/error (str e)]))))
