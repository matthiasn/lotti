(ns meo.common.specs.imap
  "Specs for sync via IMAP."
  (:require [meo.common.utils.parse :as p]
            #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])))


(s/def :sync/start-server nil?)
(s/def :sync/stop-server (s/nilable keyword?))
(s/def :sync/scan-inbox nil?)
(s/def :sync/scan-images nil?)


(s/def :meo.imap.server/host string?)
(s/def :meo.imap.server/password string?)
(s/def :meo.imap.server/user string?)
(s/def :meo.imap.server/authTimeout integer?)
(s/def :meo.imap.server/connTimeout integer?)
(s/def :meo.imap.server/port integer?)
(s/def :meo.imap.server/autotls boolean?)
(s/def :meo.imap.server/tls boolean?)

(s/def :meo.imap/server
  (s/keys :req-un [:meo.imap.server/host
                   :meo.imap.server/password
                   :meo.imap.server/user
                   :meo.imap.server/authTimeout
                   :meo.imap.server/connTimeout
                   :meo.imap.server/port
                   :meo.imap.server/autotls
                   :meo.imap.server/tls]))

(s/def :meo.imap.sync/mailbox string?)
(s/def :meo.imap.sync/secret string?)
(s/def :meo.imap.sync/last-read integer?)
(s/def :meo.imap.sync/body-part string?)

(s/def :meo.imap.sync/read
  (s/keys :req-un [:meo.imap.sync/mailbox
                   :meo.imap.sync/secret
                   :meo.imap.sync/last-read
                   :meo.imap.sync/body-part]))

(s/def :meo.imap.sync/write
  (s/keys :req-un [:meo.imap.sync/mailbox
                   :meo.imap.sync/secret]))

(s/def :meo.imap/sync
  (s/keys :req-un [:meo.imap.sync/read
                   :meo.imap.sync/write]))

(s/def :imap/cfg
  (s/keys :req-un [:meo.imap/server
                   :meo.imap/sync]))

(s/def :imap/get-cfg nil?)
