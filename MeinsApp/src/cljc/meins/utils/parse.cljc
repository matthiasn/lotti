(ns meins.utils.parse
  (:require [clojure.string :as s]))

(def tag-char-cls "[\\w\\-\\u00C0-\\u017F]")

(def entry-tag-regex
  (re-pattern (str "(?m)(?!^) ?#" tag-char-cls "+(?!" tag-char-cls ")")))
(def entry-mentions-regex
  (re-pattern (str "(?m) ?@" tag-char-cls "+(?!" tag-char-cls ")")))

(defn parse-entry
  "Parses entry for hashtags and mentions. Either can consist of any of the word
   characters, dashes and unicode characters that for example comprise German
   'Umlaute'.
   Code blocks and inline code is removed before parsing for tags."
  [text]
  (let [no-codeblocks (s/replace text (re-pattern (str "```[^`]*```")) "")
        without-code (s/replace no-codeblocks (re-pattern (str "`[^`]*`")) "")]
    {:md       text
     :tags     (conj (set (map s/trim (re-seq entry-tag-regex without-code))) "#import")
     :mentions (set (map s/trim (re-seq entry-mentions-regex without-code)))}))
