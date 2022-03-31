(ns meins.jvm.imports.spotify
  (:require [camel-snake-kebab.core :refer [->kebab-case]]
            [cheshire.core :as cc]
            [clj-http.client :as hc]
            [clj-time.coerce :as c]
            [clojure.pprint :as pp]
            [meins.jvm.file-utils :as fu]
            [taoensso.timbre :refer [error info warn]])
  (:import (java.net UnknownHostException)))

(defn body-parser [res]
  (cc/parse-string (:body res) #(keyword (->kebab-case %))))

(defn get-access-token []
  (let [client-id "30912a450a164a18b42ecdcba0097703"
        conf (fu/load-cfg)
        url "https://accounts.spotify.com/api/token"
        refresh-token (:spotify-refresh-token conf)
        client-secret (slurp "SPOTIFY_SECRET")]
    (info :get-access-token (subs refresh-token 0 6) (subs client-secret 0 6))
    (when (and refresh-token client-secret)
      (body-parser (hc/post url {:form-params {:grant_type    "refresh_token"
                                               :refresh_token refresh-token}
                                 :basic-auth  [client-id client-secret]})))))

(defn import-spotify [{:keys [put-fn]}]
  (try
    (info "Importing from Spotify.")
    (let [rp-url "https://api.spotify.com/v1/me/player/recently-played?access_token="
          item-mapper (fn [item]
                        (let [track (:track item)
                              album (:album track)
                              images (:images album)
                              artists (map (fn [a] (select-keys a [:id :uri :name]))
                                           (:artists track))]
                          {:name      (:name track)
                           :id        (:id track)
                           :uri       (:uri track)
                           :album-uri (:uri album)
                           :artists   artists
                           :image     (:url (first images))
                           :played-at (:played-at item)}))
          entry-mapper (fn [item]
                         (let [ts (c/to-long (:played-at item))]
                           {:timestamp ts
                            :md        "listened on #spotify"
                            :id        ts
                            :uri       (:uri item)
                            :tags      #{"#spotify"}
                            :spotify   item}))
          ex-handler (fn [ex] (error (.getMessage ex)))
          get (fn [url handler] (hc/get url {:async? true} handler ex-handler))
          rp-handler (fn [res]
                       (let [parsed (body-parser res)
                             recently-played (map item-mapper (:items parsed))
                             new-entries (map entry-mapper recently-played)]
                         (info "obtained response from spotify")
                         (doseq [entry new-entries]
                           (put-fn (with-meta [:entry/update entry]
                                              {:silent true})))))
          access-token (:access-token (get-access-token))
          url (str rp-url access-token)]
      (if access-token
        (get url rp-handler)
        (warn "incomplete spotify credentials")))
    (catch UnknownHostException _ (error "Host api.spotify.com not found"))
    (catch Exception ex (warn ex)))
  {})

(defn spotify-play [{:keys [msg-payload]}]
  (let [play-url "https://api.spotify.com/v1/me/player/play?access_token="
        token (:access-token (get-access-token))

        body (hc/json-encode {:uris [(:uri msg-payload)]})
        res (hc/put (str play-url token)
                    {:body         body
                     :content-type :json
                     :accept       :json})]
    (info :spotify-play msg-payload body res)
    {}))

(defn spotify-pause [{:keys [msg-payload]}]
  (let [pause-url "https://api.spotify.com/v1/me/player/pause?access_token="
        token (:access-token (get-access-token))
        res (hc/put (str pause-url token))]
    (info :spotify-pause msg-payload res)
    {}))
