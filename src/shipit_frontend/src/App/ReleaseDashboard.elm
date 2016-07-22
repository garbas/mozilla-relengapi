module App.ReleaseDashboard exposing (..) 

import Html exposing (..)
import Html.Attributes exposing (..)
import Task
import Http
import Json.Decode as Json exposing (Decoder, (:=))


-- Models

type alias User = {
  email: String,
  name: String
}

type alias UpliftRequest = {
  bugzilla_id: Int,
  author: User,
  text: String
}

type alias Bug = {
  id: Int,
  bugzilla_id: Int,
  summary: String,
  creator: User,
  assignee: User,
  uplift_request: Maybe UpliftRequest
}

type alias Analysis = {
  id: Int,
  name: String,
  bugs: List Bug
}


type alias Model = {
  -- All analysis in use
  analysis : List Analysis
}


init : (Model, Cmd Msg)
init =
  let
    model = { analysis =  [ Analysis 1 "Analysis1" [] ] }
  in
    ( 
      model, 
      -- Initial fetch of every analysis in model
      Cmd.batch <| List.map fetchAnalysis model.analysis
    )

-- Update

type Msg
   = FetchAnalysis Analysis
   | FetchAnalysisSuccess Analysis
   | FetchAnalysisFailure Http.Error


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    FetchAnalysis analysis ->
      (model, fetchAnalysis analysis)

    FetchAnalysisSuccess newAnalysis ->
      ({ model | analysis = [ newAnalysis ] }, Cmd.none)

    FetchAnalysisFailure _ ->
      (model, Cmd.none)
    
fetchAnalysis : Analysis -> Cmd Msg
fetchAnalysis analysis =
  let 
    url = "http://localhost:5000/analysis/" ++ toString analysis.id ++ "/"
  in
    Task.perform FetchAnalysisFailure FetchAnalysisSuccess (Http.get decodeAnalysis url)

decodeAnalysis : Decoder Analysis
decodeAnalysis =
  Json.object3 Analysis
    ("id" := Json.int)
    ("name" := Json.string)
    ("bugs" := Json.list decodeBug)

decodeBug : Decoder Bug
decodeBug =
  Json.object6 Bug
    ("id" := Json.int)
    ("bugzilla_id" := Json.int)
    (Json.at ["payload", "bug", "summary"] Json.string)
    (Json.at ["payload", "analysis", "users", "creator"] decodeUser)
    (Json.at ["payload", "analysis", "users", "assignee"] decodeUser)
    (Json.maybe ((Json.at ["payload", "analysis"] decodeUpliftRequest)))

decodeUser : Decoder User
decodeUser = 
  Json.object2 User
    ("email" := Json.string)
    ("real_name" := Json.string)

decodeUpliftRequest : Decoder UpliftRequest
decodeUpliftRequest  =
  Json.object3 UpliftRequest
    (Json.at ["uplift_comment", "id"] Json.int)
    ("uplift_author" := decodeUser)
    (Json.at ["uplift_comment", "raw_text"] Json.string)

-- Subscriptions

subscriptions : Analysis -> Sub Msg
subscriptions analysis =
  Sub.none


-- Views

view : Model -> Html Msg
view model =

  -- Display all analysis
  if List.isEmpty model.analysis then
    div [class "alert alert-danger"] [ text "Error: no analysis" ]
  else
    div [] 
      (List.map viewAnalysis model.analysis)

viewAnalysis: Analysis -> Html Msg
viewAnalysis analysis =
  div []
    [ h1 [] [text ("Analysis: " ++ analysis.name)]
    , div [] (List.map viewBug analysis.bugs)
    ]


viewBug: Bug -> Html Msg
viewBug bug =
  div [class "bug"] [
    h4 [] [text bug.summary],
    viewUser bug.creator "Creator",
    viewUser bug.assignee "Assignee",
    viewUpliftRequest bug.uplift_request,
    p [] [
      span [] [text ("#" ++ (toString bug.bugzilla_id))],
      a [href ("https://bugzilla.mozilla.org/show_bug.cgi?id=" ++ (toString bug.bugzilla_id)), target "_blank"] [text "View on bugzilla"]
    ],
    hr [] []
  ]

viewUser: User -> String -> Html Msg
viewUser user title = 
  div [class "user"] [
    strong [] [text (title ++ ": ")],
    a [href ("mailto:" ++ user.email)] [text user.name]
  ]

viewUpliftRequest: Maybe UpliftRequest -> Html Msg
viewUpliftRequest maybe =
  case maybe of
    Just request -> 
      div [class "uplift-request"] [
        viewUser request.author "Uplift request",
        blockquote [] [text request.text]
      ]
    Nothing -> 
      div [class "alert alert-warning"] [text "No uplift request."]

