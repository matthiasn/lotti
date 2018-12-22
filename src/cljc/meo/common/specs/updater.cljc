(ns meo.common.specs.updater
  "Specs for Updater."
  (:require [meo.common.utils.parse :as p]
            #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])))

(s/def :meo.update/status keyword?)
(s/def :meo.update/info map?)

(s/def :update/status
  (s/keys :req-un [:meo.update/status]
          :opt-un [:meo.update/info]))

(s/def :update/check nil?)
(s/def :update/check-beta nil?)
