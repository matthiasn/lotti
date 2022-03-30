(ns meins.common.specs.updater
  "Specs for Updater."
  (:require #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])))

(s/def :meins.update/status keyword?)
(s/def :meins.update/info map?)

(s/def :update/status
  (s/keys :req-un [:meins.update/status]
          :opt-un [:meins.update/info]))

(s/def :update/check nil?)
(s/def :update/check-beta nil?)
