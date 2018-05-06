(ns meo.specs
  (:require  [meo.utils.parse :as p]
    #?(:clj  [clojure.spec.alpha :as s]
       :cljs [cljs.spec.alpha :as s])))

(defn number-in-range?
  "Return function that returns true if start <= val and val < end"
  [start end]
  (fn [val]
    (and (number? val) (<= start val) (< val end))))
(def possible-timestamp? (number-in-range? 0 5000000000000))

(defn int-not-neg? [v] (and (int? v) (>= v 0)))

(defn is-tag?
  "Check if string is a tag, such as a hashtag with the '#' prefix or a mention
   with the '@' prefix."
  [prefix]
  (fn [s]
    (re-find (re-pattern (str "^" prefix p/tag-char-cls "+$")) s)))

(defn namespaced-keyword? [k] (and (keyword? k) (namespace k)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Journal Entry Specs
(s/def :iww.entry/timestamp possible-timestamp?)
(s/def :iww.entry/md string?)

(s/def :iww.entry/tags (s/coll-of (is-tag? "#")))
(s/def :iww.entry/mentions (s/coll-of (is-tag? "@")))

(s/def :iww.entry/timezone (s/nilable string?))
(s/def :iww.entry/utc-offset (number-in-range? -720 720))
(s/def :iww.entry/entry-type #{:pomodoro :story :saga})
(s/def :iww.entry/comment-for possible-timestamp?)

(s/def :iww.entry/primary-story (s/nilable possible-timestamp?))
(s/def :iww.entry/linked-stories (s/nilable
                                   #(and (set? %)
                                         (s/coll-of possible-timestamp?))))

(s/def :iww.entry/latitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :iww.entry/longitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :iww.entry/planned-dur integer?)
(s/def :iww.entry/interruptions (s/and integer? #(<= 0 %)))

(def media-file-regex #"[ A-Za-z0-9_\-]+.(jpg|JPG|PNG|png|m4v|m4a)")
(def valid-filename? #(re-find media-file-regex %))
(s/def :iww.entry/audio-file valid-filename?)
(s/def :iww.entry/img-file valid-filename?)
(s/def :iww.entry/video-file valid-filename?)

(def entry-spec
  "basic entry, with only timestamp and markdown text mandatory"
  (s/keys :req-un [:iww.entry/timestamp]
          :opt-un [:iww.entry/entry-type
                   :iww.entry/tags
                   :iww.entry/mentions
                   :iww.entry/comment-for
                   :iww.entry/primary-story
                   :iww.entry/linked-stories
                   :iww.entry/planned-dur
                   :iww.entry/completed-time
                   :iww.entry/interruptions
                   :iww.entry/timezone
                   :iww.entry/utc-offset
                   :iww.entry/latitude
                   :iww.entry/longitude
                   :iww.entry/md]))

(def entry-w-geo-spec
  "geodata-enriched entry, with timestamp, markdown text, latitude, longitude mandatory"
  (s/keys :req-un [:iww.entry/timestamp
                   :iww.entry/md
                   :iww.entry/latitude
                   :iww.entry/longitude]
          :opt-un [:iww.entry/entry-type
                   :iww.entry/tags
                   :iww.entry/mentions
                   :iww.entry/planned-dur
                   :iww.entry/completed-time
                   :iww.entry/interruptions
                   :iww.entry/timezone
                   :iww.entry/utc-offset
                   :iww.entry/audio-file
                   :iww.entry/img-file
                   :iww.entry/video-file]))

(def timestamp-required-spec (s/keys :req-un [:iww.entry/timestamp]))

;; the following message types expect a properly formed entry
(s/def :entry/new entry-spec)
(s/def :entry/update entry-spec)
;(s/def :entry/persist entry-spec)
(s/def :entry/saved entry-spec)
(s/def :entry/import entry-spec)
(s/def :entry/find timestamp-required-spec)
(s/def :entry/found entry-spec)

(s/def :import/entry entry-spec)
(s/def :import/imdb-id string?)
(s/def :import/movie (s/keys :req-un [:import/entry :import/imdb-id]))

(s/def :cmd/set-dragged timestamp-required-spec)

(s/def :ft/add entry-spec)
(s/def :ft/remove timestamp-required-spec)

;; the following message types only require timestamp to be present
(s/def :entry/remove-local timestamp-required-spec)
(s/def :entry/trash timestamp-required-spec)
(s/def :cmd/pomodoro-inc timestamp-required-spec)
(s/def :cmd/pomodoro-start timestamp-required-spec)

(s/def :cmd/toggle-active (s/keys :req-un [:set-active/timestamp
                                           :set-active/query-id]))
(s/def :cmd/toggle timestamp-required-spec)


;; toggle-key requires a map with the :path key, holding a vector with at least one of keyword, number, string
(s/def :iww.cfg/path (s/cat :first-key keyword?
                            :subsequent (s/+ (s/or :string string?
                                                   :keyword keyword?
                                                   :number number?))))
(def path-map (s/keys :req-un [:iww.cfg/path]))
(s/def :cmd/toggle-key path-map)

(s/def :cmd/set-opt (s/keys :req-un [:iww.cfg/path
                                     :iww.entry/timestamp]))

(s/def :cmd/assoc-in (s/keys :req-un [:iww.cfg/path
                                      :iww.cfg/value]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Spec
(s/def :iww.search/search-text string?)
(s/def :iww.search/tags :iww.entry/tags)
(s/def :iww.search/not-tags :iww.search/tags)
(s/def :iww.search/mentions :iww.entry/mentions)
(s/def :iww.search/date-string
  (s/nilable #(re-find #"[0-9]{4}-[0-9]{2}-[0-9]{2}" %)))
(s/def :iww.search/timestamp (s/nilable #(re-find #"[0-9]{13}" %)))
(s/def :iww.search/n pos-int?)
(s/def :iww.search/query-id keyword?)
(s/def :iww.search/tab-group keyword?)

(s/def :iww.search/search
  (s/keys :req-un [:iww.search/search-text
                   :iww.search/date-string
                   :iww.search/n
                   :iww.search/tags
                   :iww.search/not-tags
                   :iww.search/mentions
                   :iww.search/timestamp]
          :opt-un [:iww.search/query-id]))

(s/def :search/update :iww.search/search)
(s/def :state/get :iww.search/search)
(s/def :search/set-dragged (s/keys :req-un [:iww.search/query-id
                                            :iww.search/tab-group]))

(s/def :iww.search-drag/dragged :search/set-dragged)
(s/def :iww.search-drag/to :iww.search/tab-group)
(s/def :search/move-tab (s/keys :req-un [:iww.search-drag/dragged
                                         :iww.search-drag/to]))

(s/def :show/more (s/keys :req-un [:iww.search/query-id]))

(s/def :linked-filter/set (s/keys :req-un [:iww.search/search
                                           :iww.search/query-id]))

(s/def :search/add (s/keys :req-un [:iww.search/tab-group]))
(s/def :search/set-active (s/keys :req-un [:iww.search/tab-group
                                           :iww.search/query-id]))
(s/def :search/remove :search/set-active)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Result Spec
(s/def :iww.search-stats/entry-count int?)
(s/def :iww.search-stats/node-count int?)
(s/def :iww.search-stats/edge-count int?)

(def search-stats-spec
  (s/keys :req-un [:iww.search-stats/entry-count
                   :iww.search-stats/node-count
                   :iww.search-stats/edge-count]))

(s/def :iww.search-result/entries-seq (s/* possible-timestamp?))
(s/def :iww.search-result/entries
  (s/map-of (s/nilable keyword?) :iww.search-result/entries-seq) )
(s/def :iww.search-result/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :iww.search-result/hashtags (s/* string?))
(s/def :iww.search-result/mentions (s/* string?))
(s/def :iww.search-result/stats search-stats-spec)
(s/def :iww.search-result/duration-ms string?)

(s/def :state/new
  (s/keys :req-un [:iww.search-result/entries
                   :iww.search-result/entries-map
                   :iww.search-result/duration-ms]))

(s/def :state/stats-tags
  (s/keys :req-un [:iww.search-result/hashtags
                   :iww.search-result/mentions]))

(s/def :state/stats-tags2 map?)

(s/def :stats/day (s/keys :req-un [:iww.search/date-string]))
(s/def :stats/days (s/coll-of :stats/day))
(s/def :stats/type keyword?)
(s/def :stats/get (s/keys :req.un [:stats/type
                                   :stats/days]))

(s/def :pomo-stats/total int-not-neg?)
(s/def :pomo-stats/completed int-not-neg?)
(s/def :pomo-stats/started int-not-neg?)
(s/def :pomo-stats/total-time int-not-neg?)

(s/def :task-stats/tasks-cnt int-not-neg?)
(s/def :task-stats/done-cnt int-not-neg?)
(s/def :task-stats/closed-cnt int-not-neg?)

(s/def :stats/tasks-day
  (s/keys :req-un [:iww.search/date-string
                   :task-stats/tasks-cnt
                   :task-stats/done-cnt
                   :task-stats/closed-cnt]))
(s/def :stats/tasks (s/map-of :iww.search/date-string :stats/tasks-day))

(s/def :stats/result
  (s/keys :req-un [:stats/type
                   :stats/stats]))
(s/def :stats/result2 map?)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spec for :state/publish-current
(s/def :iww.ws/sente-uid string?)
(s/def :state/publish-current
  (s/keys :opt-un [:iww.ws/sente-uid]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Client Store State Spec
(s/def :iww.client-state/entries (s/* possible-timestamp?))
(s/def :iww.client-state/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :iww.client-state/last-alive possible-timestamp?)

;; map with entries as values
(s/def :iww.client-state/new-entries (s/map-of possible-timestamp? entry-spec))

(s/def :iww.client-state.cfg/active
  (s/nilable (s/map-of keyword? (s/nilable possible-timestamp?))))


(s/def :iww.query-cfg/active (s/nilable keyword?))
(s/def :iww.query-cfg/all (s/coll-of keyword?))

(s/def :iww.query-cfg/tab-group
  (s/keys :req-un [:iww.query-cfg/active
                   :iww.query-cfg/all]))

(s/def :iww.query-cfg/queries (s/map-of keyword? :iww.search/search))
(s/def :iww.query-cfg/tab-groups (s/map-of keyword? :iww.query-cfg/tab-group))

(s/def :iww.client-state/query-cfg
  (s/keys :req-un [:iww.query-cfg/queries
                   :iww.query-cfg/tab-groups]))

(s/def :iww.client-state.cfg/show-maps-for set?)
(s/def :iww.client-state.cfg/show-comments-for map?)
(s/def :iww.client-state.cfg/sort-by-upvotes boolean?)
(s/def :iww.client-state.cfg/show-all-maps boolean?)
(s/def :iww.client-state.cfg/show-hashtags boolean?)
(s/def :iww.client-state.cfg/comments-w-entries boolean?)
(s/def :iww.client-state.cfg/show-pvt boolean?)
(s/def :iww.client-state.cfg/mute boolean?)
(s/def :iww.client-state.cfg/redacted boolean?)
(s/def :iww.client-state/cfg
  (s/keys :req-un [:iww.client-state.cfg/active
                   :iww.client-state.cfg/show-maps-for
                   :iww.client-state.cfg/show-comments-for]
          :opt-un [:iww.client-state.cfg/sort-by-upvotes
                   :iww.client-state.cfg/show-all-maps
                   :iww.client-state.cfg/comments-w-entries
                   :iww.client-state.cfg/show-pvt
                   :iww.client-state.cfg/mute
                   :iww.client-state.cfg/redacted
                   :iww.client-state.cfg/show-hashtags]))

(s/def :state/client-store-spec
  (s/keys :req-un [:iww.client-state/entries
                   :iww.client-state/last-alive
                   :iww.client-state/new-entries
                   :iww.client-state/query-cfg
                   :iww.client-state/cfg]))

(s/def :state/search :iww.client-state/query-cfg)

(s/def :iww.widget-cfg/x int?)
(s/def :iww.widget-cfg/y int?)
(s/def :iww.widget-cfg/w int?)
(s/def :iww.widget-cfg/h int?)

(s/def :iww.cfg/widget-cfg
  (s/keys :req-un [:iww.widget-cfg/x
                   :iww.widget-cfg/y
                   :iww.widget-cfg/w
                   :iww.widget-cfg/h
                   :iww.widget-cfg/i]))

(s/def :iww.blink/pomodoro-completed boolean?)
(s/def :blink/busy (s/keys :req-un [:iww.blink/pomodoro-completed]))

(s/def :layout/save (s/coll-of :iww.cfg/widget-cfg))

(s/def :theme/active keyword?)
