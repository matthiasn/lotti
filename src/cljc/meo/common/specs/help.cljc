(ns meo.common.specs.help
  (:require [meo.common.utils.parse :as p]
            #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])))

(s/def :meo.manual/md string?)
(s/def :help/manual (s/keys :req-un [:meo.manual/md]))
(s/def :help/get-manual nil?)
