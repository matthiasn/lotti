(ns meins.jvm.usage
  (:require [cheshire.core :as cc]
            [clj-http.client :as client]
            [taoensso.timbre :refer [error info]]))

(defn upload-usage [data]
  (try
    (let [json (cc/generate-string data)
          res (client/post
                "https://api.meinsapp.com/v1/usage"
                {:body         json
                 :content-type :json
                 :accept       :json})]
      (info res))
    (catch Exception ex (error "upload-usage" ex))))
