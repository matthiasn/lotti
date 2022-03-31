(ns meins.jvm.imports.flight
  (:require [clj-http.client :as hc]
            [clj-time.format :as ctf]
            [clojure.string :as s]
            [net.cgrand.enlive-html :as eh]
            [taoensso.timbre :refer [error info warn]]))

(def timezones
  {"PDT"   "-07:00"
   "CLST"  "-03:00"
   "SAMT"  "+04:00"
   "CHOST" "+09:00"
   "CVT"   "-01:00"
   "SST"   "+08:00"
   "MEST"  "+02:00"
   "PST"   "+08:00"
   "ULAT"  "+08:00"
   "TFT"   "+05:00"
   "BTT"   "+06:00"
   "FKT"   "-04:00"
   "GMT"   "+00:00"
   "ADT"   "-03:00"
   "HOVT"  "+07:00"
   "HOVST" "+08:00"
   "TVT"   "+12:00"
   "AKDT"  "-08:00"
   "PGT"   "+10:00"
   "SRT"   "-03:00"
   "AWST"  "+08:00"
   "EEST"  "+03:00"
   "JST"   "+09:00"
   "MET"   "+01:00"
   "COT"   "-05:00"
   "BST"   "+01:00"
   "CWST"  "+08:45"
   "ICT"   "+07:00"
   "BIOT"  "+06:00"
   "AMT"   "+04:00"
   "UYT"   "-03:00"
   "CHUT"  "+10:00"
   "GAMT"  "-09:00"
   "IRKT"  "+08:00"
   "PKT"   "+05:00"
   "NPT"   "+05:45"
   "IRDT"  "+04:30"
   "EGT"   "-01:00"
   "AMST"  "-03:00"
   "NZDT"  "+13:00"
   "ECT"   "-05:00"
   "CEST"  "+02:00"
   "CET"   "+01:00"
   "KRAT"  "+07:00"
   "DDUT"  "+10:00"
   "TAHT"  "-10:00"
   "NCT"   "+11:00"
   "NT"    "-03:30"
   "NFT"   "+11:00"
   "AEDT"  "+11:00"
   "CHOT"  "+08:00"
   "EET"   "+02:00"
   "SAKT"  "+11:00"
   "VLAT"  "+10:00"
   "SLST"  "+05:30"
   "WAKT"  "+12:00"
   "CHST"  "+10:00"
   "USZ1"  "+02:00"
   "PMDT"  "-02:00"
   "ORAT"  "+05:00"
   "LHST"  "+11:00"
   "SAST"  "+02:00"
   "WAST"  "+02:00"
   "BDT"   "+08:00"
   "ROTT"  "-03:00"
   "NST"   "-03:30"
   "VOLT"  "+04:00"
   "ART"   "-03:00"
   "SBT"   "+11:00"
   "SGT"   "+08:00"
   "MIST"  "+11:00"
   "KGT"   "+06:00"
   "GIT"   "-09:00"
   "MST"   "-07:00"
   "AZOST" "+00:00"
   "VUT"   "+11:00"
   "RET"   "+04:00"
   "VOST"  "+06:00"
   "CHADT" "+13:45"
   "EAST"  "-06:00"
   "SYOT"  "+03:00"
   "HAEC"  "+02:00"
   "AFT"   "+04:30"
   "THA"   "+07:00"
   "OMST"  "+06:00"
   "PETT"  "+12:00"
   "IOT"   "+03:00"
   "GYT"   "-04:00"
   "TJT"   "+05:00"
   "UYST"  "-02:00"
   "HAST"  "-10:00"
   "DAVT"  "+07:00"
   "WST"   "+08:00"
   "EIT"   "+09:00"
   "TRT"   "+03:00"
   "AKST"  "-09:00"
   "CT"    "+08:00"
   "MSK"   "+03:00"
   "LINT"  "+14:00"
   "CCT"   "+06:30"
   "NUT"   "+11:00"
   "EASST" "-05:00"
   "YAKT"  "+09:00"
   "HADT"  "-09:00"
   "PHT"   "+08:00"
   "EST"   "-05:00"
   "BRT"   "-03:00"
   "DFT"   "+01:00"
   "CHAST" "+12:45"
   "TKT"   "+13:00"
   "PHOT"  "+13:00"
   "GILT"  "+12:00"
   "VET"   "-04:00"
   "NZST"  "+12:00"
   "GALT"  "-06:00"
   "ACT"   "-05:00"
   "FET"   "+03:00"
   "CLT"   "-04:00"
   "ACST"  "+09:30"
   "WIT"   "+07:00"
   "MVT"   "+05:00"
   "AZT"   "+04:00"
   "CIST"  "-08:00"
   "KOST"  "+11:00"
   "PMST"  "-03:00"
   "FJT"   "+12:00"
   "IRST"  "+03:30"
   "GFT"   "-03:00"
   "AST"   "-04:00"
   "PYT"   "-04:00"
   "ULAST" "+09:00"
   "MART"  "-09:30"
   "FNT"   "-02:00"
   "PONT"  "+11:00"
   "UTC"   "+00:00"
   "CKT"   "-10:00"
   "HKT"   "+08:00"
   "NDT"   "-02:30"
   "BIT"   "-12:00"
   "PET"   "-05:00"
   "BRST"  "-02:00"
   "TLT"   "+09:00"
   "UZT"   "+05:00"
   "EAT"   "+03:00"
   "GST"   "+04:00"
   "MDT"   "-06:00"
   "EGST"  "+00:00"
   "EDT"   "-04:00"
   "TMT"   "+05:00"
   "SRET"  "+11:00"
   "MAWT"  "+05:00"
   "KST"   "+09:00"
   "PYST"  "-03:00"
   "ACDT"  "+10:30"
   "MAGT"  "+12:00"
   "MIT"   "-09:30"
   "AEST"  "+10:00"
   "WEST"  "+01:00"
   "MYT"   "+08:00"
   "TOT"   "+13:00"
   "FKST"  "-03:00"
   "AZOT"  "-01:00"
   "YEKT"  "+05:00"
   "GET"   "+04:00"
   "COST"  "-04:00"
   "CIT"   "+08:00"
   "MHT"   "+12:00"
   "CDT"   "-04:00"
   "CST"   "-05:00"
   "IST"   "+02:00"
   "IDT"   "+03:00"
   "CXT"   "+07:00"
   "CAT"   "+02:00"
   "MMT"   "+06:30"
   "WET"   "+00:00"
   "MUT"   "+04:00"
   "SCT"   "+04:00"
   "WAT"   "+01:00"
   "BOT"   "-04:00"
   "HMT"   "+05:00"})

(defn import-flight [{:keys [put-fn msg-payload]}]
  (info "Importing from FlightAware.")
  (let [url (str "http://service.prerender.io/" (-> msg-payload :flight :url))
        ex-handler (fn [ex] (error (.getMessage ex)))
        get (fn [url handler] (hc/get url {:async? true} handler ex-handler))
        handler (fn [res]
                  (let [body (:body res)
                        el (eh/html-snippet body)
                        dur (-> el
                                (eh/select [:.flightPageProgressTotal :strong])
                                first
                                :content
                                first)
                        dist (->> (eh/select el [:.flightPageData :span])
                                  (map :content)
                                  (map first)
                                  (filter #(s/includes? % "mi"))
                                  first
                                  (re-find #"Actual: ((?:\d{1,3},)*(?:\d{3})) mi")
                                  second)
                        arrival (str
                                  (->> (eh/select el [:.flightPageSummaryArrivalDay])
                                       first
                                       :content
                                       first)
                                  " "
                                  (->> (eh/select el [:.flightPageSummaryArrival])
                                       first
                                       :content
                                       first
                                       s/trim))
                        arrival (reduce (fn [acc [k v]] (s/replace acc k v))
                                        arrival
                                        timezones)
                        fmt (ctf/formatter "E dd-MMM-yyyy HH:mma ZZ")
                        dtf (ctf/formatters :date-time)
                        arrival (ctf/parse fmt arrival)
                        details {:arrival  (ctf/unparse dtf arrival)
                                 :duration dur
                                 :miles    dist}
                        entry (update-in msg-payload [:flight] merge details)]
                    (put-fn [:entry/update entry])))]
    (get url handler))
  {})
