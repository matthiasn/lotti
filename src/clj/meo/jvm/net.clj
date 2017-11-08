(ns meo.jvm.net
  (:require [clojure.string :as s])
  (:import (java.net NetworkInterface Inet4Address)))

; ip-filter, ip-extract, and ips functions borrowed from:
; http://software-ninja-ninja.blogspot.de/2013/05/clojure-what-is-my-ip-address.html
(defn ip-filter [inet]
  (and (.isUp inet)
       (not (s/includes? (.getName inet) "vmnet"))
       (not (.isVirtual inet))
       (not (.isLoopback inet))))

(defn ip-extract [netinf]
  (let [inets (enumeration-seq (.getInetAddresses netinf))]
    (map #(vector (.getHostAddress %1) %2)
         (filter #(instance? Inet4Address %) inets)
         (repeat (.getName netinf)))))

(defn ips []
  (let [ifc (NetworkInterface/getNetworkInterfaces)]
    (mapcat ip-extract (filter ip-filter (enumeration-seq ifc)))))

(defn mac-address []
  (let [ifc (NetworkInterface/getByName (second (first (ips))))
        address (.getHardwareAddress ifc)]
    (s/join "-" (map #(format "%02X" %) address))))
