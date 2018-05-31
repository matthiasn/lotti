(ns meo.jvm.imports.git
  (:require [clojure.pprint :as pp]
            [me.raynes.conch :refer [programs let-programs]]
            [taoensso.timbre :refer [info error warn]]
            [meo.jvm.file-utils :as fu]
            [camel-snake-kebab.core :refer :all]
            [matthiasn.systems-toolbox.component :as st]
            [clj-time.coerce :as c]
            [clj-time.format :as f]
            [cheshire.core :as cc]
            [clojure.string :as s]))

(programs git)
(def rfc822-fmt (f/formatters :rfc822))

(defn set-last-read []
  (let [repos (fu/load-repos)
        recent (f/unparse rfc822-fmt (c/from-long (- (st/now) (* 60 1000))))
        updated (assoc-in repos [:last-read] recent)]
    (spit fu/repos-path (pr-str updated))))

; adapted from https://gist.github.com/varemenos/e95c2e098e657c7688fd
(defn read-repo [repo-cfg since]
  (let [{:keys [repo-name dir]} repo-cfg
        dir (str dir "/.git")
        fmt (str "--pretty=format:"
                 "{\"commit\": \"%H\",\"abbreviated_commit\": \"%h\","
                 "\"tree\": \"%T\",\"abbreviated_tree\": \"%t\",\"parent\": \"%P\","
                 "\"abbreviated_parent\": \"%p\",\"refs\": \"%D\","
                 "\"subject\": \"%s\","
                 "\"author\": {\"name\": \"%aN\",\"email\": \"%aE\",\"date\": \"%aD\"}}")
        since (or since (f/unparse rfc822-fmt (c/from-long 0)))
        since (str "--since=\"" since "\"")
        res (git "--git-dir" dir "log" fmt since)
        lines (s/split-lines res)
        mapper (fn [s]
                 (try
                   (cc/parse-string s #(keyword (->kebab-case %)))
                   (catch Exception e (error "Parsing git commit" e s))))
        commits (filter identity (map mapper lines))
        n (count commits)]
    (when (pos? n)
      (info repo-name "- read" n "commits"))
    commits))

(defn import-from-git [{:keys [put-fn]}]
  (info "reading git repos" fu/repos-path)
  (let [repos-cfg (fu/load-repos)]
    (set-last-read)
    (doseq [[repo-name repo-cfg] (:repos repos-cfg)]
      (let [commits (read-repo repo-cfg (:last-read repos-cfg))]
        (doseq [commit commits]
          (let [ts (c/to-long (-> commit :author :date))
                {:keys [abbreviated-commit author]} commit
                md ""
                entry {:git-commit (assoc-in commit [:repo-name] repo-name)
                       :timestamp  ts
                       :id         abbreviated-commit
                       :md         md
                       :text       md
                       :mentions   #{}
                       :perm_tags  #{"#git-commit"}
                       :tags       #{"#git-commit" "#import"}}]
            (when (= (:email repo-cfg) (:email author))
              (put-fn (with-meta [:entry/update entry] {:silent true}))))))))
  {})
