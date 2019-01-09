(ns meins.common.specs.help
  (:require [meins.common.utils.parse :as p]
            #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])))

(s/def :meins.manual/md string?)
(s/def :help/manual (s/keys :req-un [:meins.manual/md]))
(s/def :help/get-manual nil?)
