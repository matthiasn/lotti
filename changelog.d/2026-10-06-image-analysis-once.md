### Fixed
- **A picture could be analysed twice at once.** When a new image's automatic
  analysis was still running and the analysis was started again — from the AI
  menu, or by accepting a suggestion to analyse it — both ran, paying for two
  vision calls and storing two analyses. A request for a picture that is
  already being analysed now joins the analysis in flight.
