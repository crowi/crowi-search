_ = require "lodash"
mongodb = require "mongodb"
nroonga = require "nroonga"
moment = require "moment"
common = require "./lib"
config = require "./config"
client = mongodb.MongoClient

groongaSchema =
  fakie_page:
    def:
      name: "fakie_page"
      key_type: "ShortText"
    columns: [
      { name: "path", type: "ShortText" }
      { name: "body", type: "LongText" }
      { name: "updatedAt", type: "Time" }
    ]
  fakie_page_terms:
    def:
      name: "fakie_page_terms"
      key_type: "ShortText"
      default_tokenizer: "TokenMecab"
      flags: "TABLE_PAT_KEY|KEY_NORMALIZE"
    columns: [
      { name: "idx_path", type: "fakie_page", flags: "COLUMN_INDEX|WITH_POSITION", source: "path" }
      { name: "idx_body", type: "fakie_page", flags: "COLUMN_INDEX|WITH_POSITION", source: "body" }
    ]

db = new nroonga.Database config.database
tables = db.commandSync "table_list"

console.log tables

createTable = (schema) ->
  db.commandSync "table_create", schema.def

  for column in schema.columns
    db.commandSync "column_create", _.assign({ table: schema.def.name }, column)

# Initialize tables
for tableName, schema of groongaSchema
  console.log tableName, schema
  tableExists = false
  for table in tables
    if table.length < 2
      console.log "pass", table
      continue

    if table[1] == schema.name
      tableExists = true

  if not tableExists
    try
      createTable schema
    catch e
      console.log e

client.connect "mongodb://#{ config.mongodb.user }:#{ config.mongodb.password }@#{ config.mongodb.host }:#{ config.mongodb.port }/#{ config.mongodb.name }", (err, mongo) ->
  console.log "connected: mongodb"

  if err
    throw err

  setTimeout ->
    console.log "timeout."
    mongo.close()
  , 10*1000

  pageCollection = mongo.collection "pages"
  revisionCollection = mongo.collection "revisions"

  # pageCollection.find().limit(10).each (err, doc) -> # 10件取得 (debug)
  # pageCollection.find({$or: [{grant: null}, {grant: 1}]}).each (err, doc) -> # 全件取得
  pageCollection.find({
    updatedAt:
      $gte: moment().subtract('day', 2).toDate()
    $or: [{grant: null}, {grant: 1}]
  }).sort(updatedAt: -1).each (err, doc) -> # 最近の 2 日間を取得
    # mongo.close()

    if err or not doc
      console.log "No page: #{ err }"
      return

    console.log "Index: ", doc.path

    do (doc) ->
      doc_updatedAt = new Date(doc.updatedAt).getTime()
      doc_body = ""

      revisionCollection.find({ _id: doc.revision }).limit(1).nextObject (err, revision) ->
        if err or not revision
          console.log "No revision: #{ err }"
          return

        db.command "select", {
          table: "fakie_page"
          filter: "_key == \"#{ doc._id }\""
          limit: 1
        }, (err, data) ->
          data = common.format_groonga_data data

          if data.length == 0
            # console.log "No record: #{ doc._id }"
          else
            # console.log "Find: #{ doc._id }"
            row = data.shift()

            if row.updatedAt == doc_updatedAt
              # console.log "skip"
              return

          db.command "load", {
            table: "fakie_page"
            input_type: "json"
            values: JSON.stringify [
              {
                _key: doc._id
                path: doc.path
                body: revision.body
                updatedAt: doc_updatedAt
              }
            ]
          }, (err, data) ->
            console.log "db.command load" , err, data

