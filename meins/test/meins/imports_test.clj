(ns meins.imports-test
  "Here, we test the handler functions of the imports component."
  (:require [clojure.test :refer [deftest is testing]]
            [meins.jvm.imports :as i]
            [meins.jvm.imports.media :as im]))

(def test-exif
  {"GPS Latitude Ref" "N"
   "GPS Latitude"     "53° 32' 41.2\""})

(deftest dms-to-dd-test
  (is (= (float 53.544777)
         (im/dms-to-dd test-exif "GPS Latitude" "GPS Latitude Ref"))))

(deftest cmp-map-test
  (testing "cmp-map contains required keys"
    (let [cmp-id :server/ft-cmp
          cmp-map (i/cmp-map cmp-id)
          handler-map (:handler-map cmp-map)]
      (is (= (:cmp-id cmp-map) cmp-id))
      (is (fn? (:import/photos handler-map)))
      (is (fn? (:import/movie handler-map))))))
