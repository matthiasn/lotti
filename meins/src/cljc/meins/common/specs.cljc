(ns meins.common.specs
  (:require #?(:clj [clojure.spec.alpha :as s]
               :cljs [cljs.spec.alpha :as s])
            [meins.common.specs.imap]
            [meins.common.specs.updater]
            [meins.common.utils.parse :as p]))

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
(s/def :meins.entry/timestamp possible-timestamp?)
(s/def :meins.entry/md string?)

(s/def :meins.entry/tags (s/coll-of (is-tag? "#")))
(s/def :meins.entry/mentions (s/coll-of (is-tag? "@")))

(s/def :meins.entry/timezone (s/nilable string?))
(s/def :meins.entry/utc-offset (number-in-range? -720 720))

(s/def :meins.entry/entry-type
  (s/nilable #{:pomodoro
               :story
               :saga
               :problem
               :problem-review
               :habit
               :dashboard-cfg
               :custom-field-cfg}))

(s/def :meins.entry/comment-for possible-timestamp?)

(s/def :meins.entry/primary-story (s/nilable possible-timestamp?))
(s/def :meins.entry/linked-stories (s/nilable
                                   #(and (set? %)
                                         (s/coll-of possible-timestamp?))))

(s/def :meins.entry/latitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :meins.entry/longitude (s/nilable (number-in-range? -180.0 180.0)))
(s/def :meins.entry/geohash string?)
(s/def :meins.entry/planned-dur integer?)
(s/def :meins.entry/interruptions (s/and integer? #(<= 0 %)))

(def media-file-regex #"[ A-Za-z0-9_\-]+.(jpg|JPG|PNG|png|m4v|m4a)")
(def valid-filename? #(re-find media-file-regex %))
(s/def :meins.entry/audio-file valid-filename?)
(s/def :meins.entry/img-file valid-filename?)
(s/def :meins.entry/video-file valid-filename?)

(def entry-spec
  "basic entry, with only timestamp and markdown text mandatory"
  (s/keys :req-un [:meins.entry/timestamp]
          :opt-un [:meins.entry/entry-type
                   :meins.entry/tags
                   :meins.entry/mentions
                   :meins.entry/comment-for
                   :meins.entry/primary-story
                   :meins.entry/linked-stories
                   :meins.entry/planned-dur
                   :meins.entry/completed-time
                   :meins.entry/interruptions
                   :meins.entry/timezone
                   :meins.entry/utc-offset
                   :meins.entry/geohash
                   :meins.entry/latitude
                   :meins.entry/longitude
                   :meins.entry/md]))
(s/def :meins.entry/spec entry-spec)

(def entry-w-geo-spec
  "geodata-enriched entry, with timestamp, markdown text, latitude, longitude mandatory"
  (s/keys :req-un [:meins.entry/timestamp
                   :meins.entry/md
                   :meins.entry/latitude
                   :meins.entry/longitude]
          :opt-un [:meins.entry/entry-type
                   :meins.entry/tags
                   :meins.entry/mentions
                   :meins.entry/planned-dur
                   :meins.entry/completed-time
                   :meins.entry/interruptions
                   :meins.entry/timezone
                   :meins.entry/utc-offset
                   :meins.entry/audio-file
                   :meins.entry/img-file
                   :meins.entry/video-file]))

(def timestamp-required-spec (s/keys :req-un [:meins.entry/timestamp]))

;; the following message types expect a properly formed entry
(s/def :entry/update-local entry-spec)
(s/def :entry/update entry-spec)
(s/def :entry/save-initial entry-spec)
(s/def :entry/briefing entry-spec)
(s/def :entry/saved entry-spec)
(s/def :entry/import entry-spec)
(s/def :sync/imap entry-spec)
(s/def :sync/read-imap nil?)
(s/def :sync/start-imap nil?)

(s/def :entry/create map?)

(s/def :import/entry entry-spec)
(s/def :entry/sync entry-spec)
(s/def :import/imdb-id string?)
(s/def :import/movie (s/keys :req-un [:import/entry :import/imdb-id]))

(s/def :cmd/set-dragged entry-spec)

(s/def :ft/add entry-spec)
(s/def :ft/remove timestamp-required-spec)

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
(s/def :meins.cfg/path (s/cat :first-key keyword?
                            :subsequent (s/+ (s/or :string string?
                                                   :keyword keyword?
                                                   :number number?))))
(def path-map (s/keys :req-un [:meins.cfg/path]))
(s/def :cmd/toggle-key path-map)

(s/def :cmd/set-opt (s/keys :req-un [:meins.cfg/path
                                     :meins.entry/timestamp]))

(s/def :cmd/assoc-in (s/keys :req-un [:meins.cfg/path
                                      :meins.cfg/value]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Spec
(s/def :meins.search/search-text string?)
(s/def :meins.search/tags :meins.entry/tags)
(s/def :meins.search/not-tags :meins.search/tags)
(s/def :meins.search/mentions :meins.entry/mentions)
(s/def :meins.search/date_string
  (s/nilable #(re-find #"[0-9]{4}-[0-9]{2}-[0-9]{2}" %)))
(s/def :meins.search/timestamp (s/nilable #(re-find #"[0-9]{13}" %)))
(s/def :meins.search/n pos-int?)
(s/def :meins.search/story (s/nilable possible-timestamp?))
(s/def :meins.search/query-id keyword?)
(s/def :meins.search/tab-group keyword?)

(s/def :meins.search/search
  (s/keys :req-un [:meins.search/search-text
                   :meins.search/date_string
                   :meins.search/n
                   :meins.search/tags
                   :meins.search/not-tags
                   :meins.search/mentions
                   :meins.search/timestamp]
          :opt-un [:meins.search/query-id]))

(s/def :search/update :meins.search/search)
(s/def :state/get :meins.search/search)
(s/def :search/set-dragged (s/keys :req-un [:meins.search/query-id
                                            :meins.search/tab-group]))

(s/def :meins.search/t #{:close-tab :next-tab :active-tab})
(s/def :search/cmd (s/keys :req-un [:meins.search/t]))

(s/def :meins.search-drag/dragged :search/set-dragged)
(s/def :meins.search-drag/to :meins.search/tab-group)
(s/def :search/move-tab (s/keys :req-un [:meins.search-drag/dragged
                                         :meins.search-drag/to]))

(s/def :show/more (s/keys :req-un [:meins.search/query-id]))

(s/def :linked-filter/set (s/keys :req-un [:meins.search/search
                                           :meins.search/query-id]))

(s/def :search/add (s/keys :req-un [:meins.search/tab-group]))
(s/def :search/set-active (s/keys :req-un [:meins.search/tab-group
                                           :meins.search/query-id]))
(s/def :search/remove (s/keys :req-un [:meins.search/tab-group]
                              :opt-un [:meins.search/query-id]))
(s/def :search/remove-all (s/keys :req-un [:meins.search/search-text]
                                  :opt-un [:meins.search/story]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search Result Spec
(s/def :meins.search-stats/entry-count int?)
(s/def :meins.search-stats/node-count int?)
(s/def :meins.search-stats/edge-count int?)

(def search-stats-spec
  (s/keys :req-un [:meins.search-stats/entry-count
                   :meins.search-stats/node-count
                   :meins.search-stats/edge-count]))

(s/def :meins.search-result/entries-seq (s/* possible-timestamp?))
(s/def :meins.search-result/entries
  (s/map-of (s/nilable keyword?) :meins.search-result/entries-seq))
(s/def :meins.search-result/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :meins.search-result/hashtags (s/* string?))
(s/def :meins.search-result/mentions (s/* string?))
(s/def :meins.search-result/stats search-stats-spec)
(s/def :meins.search-result/duration-ms string?)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spec for :state/publish-current
(s/def :meins.ws/sente-uid string?)
(s/def :state/publish-current
  (s/keys :opt-un [:meins.ws/sente-uid]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Client Store State Spec
(s/def :meins.client-state/entries-map (s/map-of possible-timestamp? entry-spec))
(s/def :meins.client-state/last-alive possible-timestamp?)

;; map with entries as values
(s/def :meins.client-state/new-entries (s/map-of possible-timestamp? entry-spec))

(s/def :meins.client-state.cfg/active
  (s/nilable (s/map-of keyword? (s/nilable possible-timestamp?))))


(s/def :meins.query-cfg/active (s/nilable keyword?))
(s/def :meins.query-cfg/all (s/coll-of keyword?))

(s/def :meins.query-cfg/tab-group
  (s/keys :req-un [:meins.query-cfg/all]
          :opt-un [:meins.query-cfg/active]))

(s/def :meins.query-cfg/queries (s/map-of keyword? :meins.search/search))
(s/def :meins.query-cfg/tab-groups (s/map-of keyword? :meins.query-cfg/tab-group))

(s/def :meins.client-state/query-cfg
  (s/keys :req-un [:meins.query-cfg/queries]
          :opt-un [:meins.query-cfg/tab-groups]))

(s/def :meins.client-state.cfg/show-maps-for set?)
(s/def :meins.client-state.cfg/show-comments-for map?)
(s/def :meins.client-state.cfg/sort-by-upvotes boolean?)
(s/def :meins.client-state.cfg/show-all-maps boolean?)
(s/def :meins.client-state.cfg/show-hashtags boolean?)
(s/def :meins.client-state.cfg/comments-w-entries boolean?)
(s/def :meins.client-state.cfg/show-pvt boolean?)
(s/def :meins.client-state.cfg/mute boolean?)
(s/def :meins.client-state.cfg/redacted boolean?)
(s/def :meins.client-state/cfg
  (s/keys :req-un [:meins.client-state.cfg/active
                   :meins.client-state.cfg/show-maps-for
                   :meins.client-state.cfg/show-comments-for]
          :opt-un [:meins.client-state.cfg/sort-by-upvotes
                   :meins.client-state.cfg/show-all-maps
                   :meins.client-state.cfg/comments-w-entries
                   :meins.client-state.cfg/show-pvt
                   :meins.client-state.cfg/mute
                   :meins.client-state.cfg/redacted
                   :meins.client-state.cfg/show-hashtags]))

(s/def :state/client-store-spec
  (s/keys :req-un [:meins.client-state/last-alive
                   :meins.client-state/new-entries
                   :meins.client-state/query-cfg
                   :meins.client-state/cfg]))

(s/def :state/search :meins.client-state/query-cfg)

(s/def :meins.widget-cfg/x int?)
(s/def :meins.widget-cfg/y int?)
(s/def :meins.widget-cfg/w int?)
(s/def :meins.widget-cfg/h int?)

(s/def :meins.cfg/widget-cfg
  (s/keys :req-un [:meins.widget-cfg/x
                   :meins.widget-cfg/y
                   :meins.widget-cfg/w
                   :meins.widget-cfg/h
                   :meins.widget-cfg/i]))

(s/def :meins.blink/color #{:green :orange :red})
(s/def :blink/busy (s/keys :req-un [:meins.blink/color]))

(s/def :layout/save (s/coll-of :meins.cfg/widget-cfg))

(s/def :wm/open-external string?)

(s/def :geonames/lookup map?)
(s/def :geonames/res map?)

(s/def :import/git nil?)
(s/def :import/spotify nil?)
(s/def :import/listen nil?)
(s/def :import/stop-server nil?)
(s/def :cfg/refresh nil?)
(s/def :ws/ping nil?)
(s/def :state/persist nil?)

(s/def :wm.progress/v number?)
(s/def :window/progress (s/keys :req-un [:wm.progress/v]))

(s/def :startup/progress (s/map-of :keyword number?))
(s/def :startup/read nil?)

(s/def :meins.enc/filename string?)
(s/def :file/encrypt (s/keys :req-un [:meins.enc/filename]))

(s/def :meins.gql/id keyword?)
(s/def :meins.gql/file string?)
(s/def :meins.gql/data map?)

(s/def :gql/query (s/keys :req-un [:meins.gql/id]
                          :opt-un [:meins.gql/file
                                   :meins.gql/args]))

(s/def :gql/res (s/keys :req-un [:meins.gql/id]
                        :opt-un [:meins.gql/file
                                 :meins.gql/args
                                 :meins.gql/data
                                 :meins.gql/error]))

(s/def :gql/run-registered (s/nilable map?))
(s/def :options/gen nil?)

(s/def :backend-cfg/new map?)

(s/def :meins.cal/day :meins.search/date_string)
(s/def :cal/to-day (s/keys :req-un [:meins.cal/day]))

(s/def :window/show nil?)
(s/def :screenshot/take nil?)
(s/def :import/screenshot map?)

(s/def :meins.photo/filename string?)
(s/def :meins.photo/full-path string?)
(s/def :import/gen-thumbs (s/keys :req-un [:meins.photo/filename
                                           :meins.photo/full-path]))

(s/def :playground/gen nil?)

(s/def :metrics/info map?)
