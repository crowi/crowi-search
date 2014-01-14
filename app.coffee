###
app.coffee
###

express = require "express"
nroonga = require "nroonga"
pagination = require "pagination"
moment = require "moment"
common = require "./lib"
config = require "./config"

app = express()
db = new nroonga.Database config.database

# Configure
app.configure ->
  app.set "views", "#{ __dirname }/views"
  app.set "view engine", "jade"
  app.set "port", process.env.PORT || 12222
  app.use express.logger()

app.configure "development", ->
  app.use express.errorHandler(dumpExceptions: true, showStack: true)

# Router
app.get "/", (req, res) ->
  console.log 0 | 2
  res.render "index"

app.get "/search", (req, res) ->
  PERPAGE = 30

  if not "q" of req.query
    res.redirect "/"

  page = req.query.page || 1

  db.command "select", {
    table: "fakie_page"
    query: req.query.q
    output_columns: "_id,_score,_key,path,body,updatedAt"
    match_columns: "path * 2 || body"
    sortby: '-_score'
    offset: (page - 1) * PERPAGE
  }, (err, results) ->
    total = results[0][0][0]
    paginator = pagination.create 'search',
      prelink: "/search?q=#{ req.query.q }"
      current: page
      rowsPerPage: PERPAGE
      totalResult: total

    # pagination.render for bootstrap
    paginator.render = ->
      result = @getPaginationData()
      html = ['<ul class="pagination">']

      if result.pageCount > 2
        prelink = @preparePreLink result.prelink

        if result.previous
          html.push """
          <li><a href="#{ prelink }#{ result.previous }">#{ @options.translator("PREVIOUS") }</a></li>
          """

        if result.range.length
          len = result.range.length - 1
          if len > 5
            len = 5
          for i in [0..len]
            if result.range[i] is result.current
              className = "active"
            else
              className = ""

            html.push """
            <li class="#{ className }"><a href="#{ prelink }#{ result.range[i] }">#{ result.range[i] }</a></li>
            """

        if result.next
          html.push """
          <li><a href="#{ prelink }#{ result.next }">#{ @options.translator("NEXT") }</a></li>
          """

      html.push "</ul>"
      html.join("")
    # ==

    results = common.format_groonga_data results

    if req.query.type is "json"
      res.jsonp results
      return

    res.render "search",
      moment: moment
      q: req.query.q
      results: results
      total: total
      paginator: paginator

# Run
app.listen app.set("port"), ->
  console.log "Listening on port #{ app.set("port") }"
