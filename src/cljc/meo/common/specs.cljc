(ns meo.common.specs
  (:require [meo.common.utils.parse :as p]
    #?(:clj
            [clojure.spec.alpha :as s]
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
(s/def :meo.entry/timestamp possible-timestamp?)
(s/def :meo.entry/md string?)

(s/def :meo.entry/tags (s/coll-of (is-tag? "#")))
(s/def :meo.entry/mentions (s/coll-of (is-tag? "@")))

(s/def :meo.entry/timezone (s/nilable string?))
(s/def :meo.entry/utc-offset (number-in-range? -720 720))
(s/def :meo.entry/entry-type #{:pomodoro :story :saga})
(s/def :meo.entry/comment-for possible-timestamp?)

(s/def :meo.entry/primary-story (s/nilable possible-timestamp?))
(s/def :meo.entry/linked-stories (s/nilable
                                   #(and (set? %)
                                         (s/coll-of possible-timestamp?))))

(s/def :meo.entry/latitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :meo.entry/longitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :meo.entry/planned-dur integer?)
(s/def :meo.entry/interruptions (s/and integer? #(<= 0 %)))

(def media-file-regex #"[ A-Za-z0-9_\-]+.(jpg|JPG|PNG|png|m4v|m4a)")
(def valid-filename? #(re-find media-file-regex %))
(s/def :meo.entry/audio-file valid-filename?)
(s/def :meo.entry/img-file valid-filename?)
(s/def :meo.entry/video-file valid-filename?)

(def entry-spec
  "basic entry, with only timestamp and markdown text mandatory"
  (s/keys :req-un [:meo.entry/timestamp]
          :opt-un [:meo.entry/entry-type
                   :meo.entry/tags
                   :meo.entry/mentions
                   :meo.entry/comment-for
                   :meo.entry/primary-story
                   :meo.entry/linked-stories
                   :meo.entry/planned-dur
                   :meo.entry/completed-time
                   :meo.entry/interruptions
                   :meo.entry/timezone
                   :meo.entry/utc-offset
                   :meo.entry/latitude
                   :meo.entry/longitude
                   :meo.entry/md]))

(def entry-w-geo-spec
  "geodata-enriched entry, with timestamp, markdown text, latitude, longitude mandatory"
  (s/keys :req-un [:meo.entry/timestamp
                   :meo.entry/md
                   :meo.entry/latitude
                   :meo.entry/longitude]
          :opt-un [:meo.entry/entry-type
                   :meo.entry/tags
                   :meo.entry/mentions
                   :meo.entry/planned-dur
                   :meo.entry/completed-time
                   :meo.entry/interruptions
                   :meo.entry/timezone
                   :meo.entry/utc-offset
                   :meo.entry/audio-file
                   :meo.entry/img-file
                   :meo.entry/video-file]))

(def timestamp-required-spec (s/keys :req-un [:meo.entry/timestamp]))

;; the following message types expect a properly formed entry
(s/def :entry/new entry-spec)
(s/def :entry/update-local entry-spec)
(s/def :entry/update entry-spec)
(s/def :entry/briefing entry-spec)
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

;; geo-enriched entries require a properly formed entry with latitude and longitude
(s/def :entry/geo-enrich entry-w-geo-spec)

;; the following message types only require timestamp to be present
(s/def :entry/remove-local timestamp-required-spec)
(s/def :entry/trash timestamp-required-spec)
(s/def :entry/unlink (s/coll-of possible-timestamp?))

(s/def :cmd/pomodoro-inc timestamp-required-spec)
(s/def :cmd/pomodoro-start timestamp-required-spec)

(s/def :cmd/toggle-active (s/keys :req-un [:set-active/timestamp
                                           :set-active/query-id]))
(s/def :cmd/toggle timestamp-required-spec)


;; toggle-key requires a map with the :path key, holding a vector with at least one of keyword, number, string
(s/def :meo.cfg/path (s/cat :first-key keyword?
                            :subsequent (s/+ (s/or :string string?
                                                   :keyword keyword?
                                                   :number number?))))
(def path-map (s/keys :req-un [:meo.cfg/path]))
(s/def :cmd/toggle-key path-map)

(s/def :cmd/set-opt (s/keys :req-un [:meo.cfg/path
                                     :meo.entry/timestamp]))

(s/def :cmd/assoc-in (s/keys :req-un [:meo.cfg/path
                                      :meo.cfg/value]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Spec
(s/def :meo.search/search-text string?)
(s/def :meo.search/tags :meo.entry/tags)
(s/def :meo.search/not-tags :meo.search/tags)
(s/def :meo.search/mentions :meo.entry/mentions)
(s/def :meo.search/date-string
  (s/nilable #(re-find #"[0-9]{4}-[0-9]{2}-[0-9]{2}" %)))
(s/def :meo.search/timestamp (s/nilable #(re-find #"[0-9]{13}" %)))
(s/def :meo.search/n pos-int?)
(s/def :meo.search/story (s/nilable possible-timestamp?))
(s/def :meo.search/query-id keyword?)
(s/def :meo.search/tab-group keyword?)

(s/def :meo.search/search
  (s/keys :req-un [:meo.search/search-text
                   :meo.search/date-string
                   :meo.search/n
                   :meo.search/tags
                   :meo.search/not-tags
                   :meo.search/mentions
                   :meo.search/timestamp]
          :opt-un [:meo.search/query-id]))

(s/def :search/update :meo.search/search)
(s/def :state/get :meo.search/search)
(s/def :search/set-dragged (s/keys :req-un [:meo.search/query-id
                                            :meo.search/tab-group]))

(s/def :meo.search-drag/dragged :search/set-dragged)
(s/def :meo.search-drag/to :meo.search/tab-group)
(s/def :search/move-tab (s/keys :req-un [:meo.search-drag/dragged
                                         :meo.search-drag/to]))

(s/def :show/more (s/keys :req-un [:meo.search/query-id]))

(s/def :linked-filter/set (s/keys :req-un [:meo.search/search
                                           :meo.search/query-id]))

(s/def :search/add (s/keys :req-un [:meo.search/tab-group]))
(s/def :search/set-active (s/keys :req-un [:meo.search/tab-group
                                           :meo.search/query-id]))
(s/def :search/remove (s/nilable :search/set-active))
(s/def :search/remove-all (s/keys :req-un [:meo.search/story
                                           :meo.search/search-text]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Result Spec
(s/def :meo.search-stats/entry-count int?)
(s/def :meo.search-stats/node-count int?)
(s/def :meo.search-stats/edge-count int?)

(def search-stats-spec
  (s/keys :req-un [:meo.search-stats/entry-count
                   :meo.search-stats/node-count
                   :meo.search-stats/edge-count]))

(s/def :meo.search-result/entries-seq (s/* possible-timestamp?))
(s/def :meo.search-result/entries
  (s/map-of (s/nilable keyword?) :meo.search-result/entries-seq))
(s/def :meo.search-result/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :meo.search-result/hashtags (s/* string?))
(s/def :meo.search-result/mentions (s/* string?))
(s/def :meo.search-result/stats search-stats-spec)
(s/def :meo.search-result/duration-ms string?)

(s/def :state/new
  (s/keys :req-un [:meo.search-result/entries
                   :meo.search-result/entries-map
                   :meo.search-result/duration-ms]))

(s/def :stats/day (s/keys :req-un [:meo.search/date-string]))
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

(s/def :stats/result
  (s/keys :req-un [:stats/type
                   :stats/stats]))
(s/def :stats/result2 map?)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spec for :state/publish-current
(s/def :meo.ws/sente-uid string?)
(s/def :state/publish-current
  (s/keys :opt-un [:meo.ws/sente-uid]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Client Store State Spec
(s/def :meo.client-state/entries (s/* possible-timestamp?))
(s/def :meo.client-state/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :meo.client-state/last-alive possible-timestamp?)

;; map with entries as values
(s/def :meo.client-state/new-entries (s/map-of possible-timestamp? entry-spec))

(s/def :meo.client-state.cfg/active
  (s/nilable (s/map-of keyword? (s/nilable possible-timestamp?))))


(s/def :meo.query-cfg/active (s/nilable keyword?))
(s/def :meo.query-cfg/all (s/coll-of keyword?))

(s/def :meo.query-cfg/tab-group
  (s/keys :req-un [:meo.query-cfg/all]
          :opt-un [:meo.query-cfg/active]))

(s/def :meo.query-cfg/queries (s/map-of keyword? :meo.search/search))
(s/def :meo.query-cfg/tab-groups (s/map-of keyword? :meo.query-cfg/tab-group))

(s/def :meo.client-state/query-cfg
  (s/keys :req-un [:meo.query-cfg/queries]
          :opt-un [:meo.query-cfg/tab-groups]))

(s/def :meo.client-state.cfg/show-maps-for set?)
(s/def :meo.client-state.cfg/show-comments-for map?)
(s/def :meo.client-state.cfg/sort-by-upvotes boolean?)
(s/def :meo.client-state.cfg/show-all-maps boolean?)
(s/def :meo.client-state.cfg/show-hashtags boolean?)
(s/def :meo.client-state.cfg/comments-w-entries boolean?)
(s/def :meo.client-state.cfg/show-pvt boolean?)
(s/def :meo.client-state.cfg/mute boolean?)
(s/def :meo.client-state.cfg/redacted boolean?)
(s/def :meo.client-state/cfg
  (s/keys :req-un [:meo.client-state.cfg/active
                   :meo.client-state.cfg/show-maps-for
                   :meo.client-state.cfg/show-comments-for]
          :opt-un [:meo.client-state.cfg/sort-by-upvotes
                   :meo.client-state.cfg/show-all-maps
                   :meo.client-state.cfg/comments-w-entries
                   :meo.client-state.cfg/show-pvt
                   :meo.client-state.cfg/mute
                   :meo.client-state.cfg/redacted
                   :meo.client-state.cfg/show-hashtags]))

(s/def :state/client-store-spec
  (s/keys :req-un [:meo.client-state/entries
                   :meo.client-state/last-alive
                   :meo.client-state/new-entries
                   :meo.client-state/query-cfg
                   :meo.client-state/cfg]))

(s/def :state/search :meo.client-state/query-cfg)

(s/def :meo.widget-cfg/x int?)
(s/def :meo.widget-cfg/y int?)
(s/def :meo.widget-cfg/w int?)
(s/def :meo.widget-cfg/h int?)

(s/def :meo.cfg/widget-cfg
  (s/keys :req-un [:meo.widget-cfg/x
                   :meo.widget-cfg/y
                   :meo.widget-cfg/w
                   :meo.widget-cfg/h
                   :meo.widget-cfg/i]))

(s/def :meo.blink/color #{:green :orange :red})
(s/def :blink/busy (s/keys :req-un [:meo.blink/color]))

(s/def :layout/save (s/coll-of :meo.cfg/widget-cfg))

(s/def :wm/open-external string?)

(s/def :geonames/lookup map?)
(s/def :geonames/res map?)

(s/def :search/refresh nil?)
(s/def :import/git nil?)
(s/def :import/spotify nil?)
(s/def :import/listen nil?)
(s/def :import/stop-server nil?)
(s/def :state/stats-tags-get nil?)
(s/def :stats/get2 nil?)
(s/def :cfg/refresh nil?)
(s/def :ws/ping nil?)

(s/def :wm.progress/v number?)
(s/def :window/progress (s/keys :req-un [:wm.progress/v]))

(s/def :sync/start-server nil?)
(s/def :sync/stop-server (s/nilable keyword?))
(s/def :sync/scan-inbox nil?)
(s/def :sync/scan-images nil?)

(s/def :startup/progress number?)
(s/def :startup/read nil?)

(s/def :meo.enc/filename string?)
(s/def :file/encrypt (s/keys :req-un [:meo.enc/filename]))

(s/def :meo.update/status (s/map-of keyword? keyword?))

(s/def :meo.gql/id keyword?)
(s/def :meo.gql/file string?)
(s/def :meo.gql/data map?)

(s/def :gql/query (s/keys :req-un [:meo.gql/id]
                          :opt-un [:meo.gql/file
                                   :meo.gql/args]))

(s/def :gql/res (s/keys :req-un [:meo.gql/id]
                          :opt-un [:meo.gql/file
                                   :meo.gql/args
                                   :meo.gql/data
                                   :meo.gql/error]))

(s/def :meo.cal/day :meo.search/date-string)
(s/def :cal/to-day (s/keys :req-un [:meo.cal/day]))
