(ns meins.jvm.usage
  (:require [cheshire.core :as cc]
            [taoensso.timbre :refer [info error]]
            [clj-http.client :as client]))

(defn upload-usage [data]
  (try
    (let [json (cc/generate-string data)
          res (client/post
                "https://api.meinsapp.com/v1/usage"
                {:body         json
                 :content-type :json
                 :accept       :json
                 :insecure?    true})]
      (info res))
    (catch Exception ex (error "upload-usage" ex))))
