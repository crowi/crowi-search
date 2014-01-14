module.exports =
  format_groonga_data: (arr) ->
    results = arr[0]
    data = []
    keys = []

    meta = results.shift()
    head = results.shift()

    for field in head
      keys[keys.length] = field[0]

    for result in results
      do (result) ->
        row = {}

        for key, i in keys
          row[key] = result[i]

        data[data.length] = row

    data
