
extractFields = (obj) ->
    fields = []
    for own k, v of obj
        fields.push {name: k}
    fields.filter (x) -> x not in facts

dataString = (fields, dataPoint) ->
    key = ""
    for name in fields
        key = key + "-" + dataPoint[name]
    return key

groupByFields = (fields, data) ->
    keyedData = data.map (d) -> {key: dataString(fields, d), value: d}

    groupedData = {}
    for kvp in keyedData
        (groupedData[kvp.key] or= []).push kvp
    return groupedData

#aggregate functions
mean = (kvpSeq) ->
    acc = {}
    for {key, value} in kvpSeq
        n = (acc[value.x] or {x: value.x, count: 0, sum: 0})
        acc[value.x] = { x: value.x, count: n.count + 1, sum: n.sum + value.y }
    localLst = []
    for a, b of acc
        localLst.push b
    return localLst.map (d) -> [d.x, d.sum/d.count]

sum = (kvpSeq) ->
    acc = {}
    for {key, value} in kvpSeq
        n = (acc[value.x] or {x: value.x, sum: 0})
        acc[value.x] = {x: value.x, sum: n.sum + value.y}
    res = []
    for a, b of acc
        res.push b
    return res.map (d) -> [d.x, d.sum]

count = (kvpSeq) ->
    acc = {}
    for {key, value} in kvpSeq
        n = (acc[value.x] or {x: value.x, count: 0})
        acc[value.x] = {x: value.x, count: n.count + 1}
    res = []
    for a, b of acc
        res.push b
    return res.map (d) -> [d.x, d.count]

max = (kvpSeq) ->
    acc = {}
    for {key, value} in kvpSeq
        n = (acc[value.x] or {x: value.x, max: 0})
        localMax = if n.max > value.y then n.max else value.y
        acc[value.x] = {x: value.x, max: localMax}
    res = []
    for a, b of acc
        res.push b
    return res.map (d) -> [d.x, d.max]

min = (kvpSeq) ->
    acc = {}
    for {key, value} in kvpSeq
        n = (acc[value.x] or {x: value.x, min: value.y})
        localMin = if n.min < value.y then n.min else value.y
        acc[value.x] = {x: value.x, min: localMin}
    res = []
    for a, b of acc
        res.push b
    return res.map (d) -> [d.x, d.min]    

#median = (kvpSeq) ->
#    acc = {}
#    for {key, value} in kvpSeq
#        mid = (acc[value.x] or= {x: value.x, lst: []})
#        mid.lst.push value.y
#        acc[value.x] = {x: mid.x, lst: mid.lst}
#    res = []
#    for a, b of acc



mapToPoints = (groupedData, xFunc, yField) ->
    groupedPoints = {}
    for own k, g of groupedData
        (groupedPoints[k] or= []).push g.map (d) -> {key: d.key, value: {x: xFunc(d.value), y: d.value[yField]}}
    groupedPoints

aggregate = (groupingFields, op, xFunc, yField, data) ->
    groupedData = groupByFields(groupingFields, data)
    mappedPoints = mapToPoints(groupedData, xFunc, yField)

    aggregatedData = {}
    for own groupingKey, group of mappedPoints
        byTs = {}
        for lst in group
            aggregatedData[groupingKey] = op(lst)

    return aggregatedData

#csv utility method. Should really be in its own .js file
exportAsCSV = (data) ->
    console.log data?
    if data == {}
        alert "Fetch some data first."
        return

    header = []
    for own k, v of data[0]
        header.push k
    body = []
    for d in data
        row = []
        for own key, value of d
            row.push value
        body.push row

    csv = "data:text/csv;charset=utf-8,"
    csv += header.join(",") + "\n"

    for r in body
        csv += r.join(",") + "\n"

    return csv

toKvp = (aggregates) ->
    formattedData = []      
    for own category, group of aggregates
        formattedData.push {key: category, values: group}

type = (obj) ->
    if obj == undefined or obj == null
      return String obj
    classToType = {
      '[object Boolean]': 'boolean',
      '[object Number]': 'number',
      '[object String]': 'string',
      '[object Function]': 'function',
      '[object Array]': 'array',
      '[object Date]': 'date',
      '[object RegExp]': 'regexp',
      '[object Object]': 'object'
    }
    return classToType[Object.prototype.toString.call(obj)]

#basic configuration classes
class AggregateConfiguration
    operators: [{name:"Mean", func: mean}, {name:"Sum", func: sum}, {name: "Count", func: count}, {name: "Max", func: max}, {name: "Min", func: min}]

class AggregationSettings
    facts: []
    dimensions: []
    tab: {}
    startDate: {}
    endDate: {}
    groupByFields: []
    aggFunction: {}
    currentFact: {}
    xAxis: {}



latency = window.angular.module('latency', ['ng'])

latency.controller('latencyCtrl', ($scope, $http, $window) ->
    
    retrievePreferences = () ->
        keys = []
        for k, v of $window.localStorage
            if /View-/.test(k)
                n = k.replace /View-/, ""
                keys.push {name: n, value: v}
        keys

    $scope.configuration = new AggregateConfiguration
    $scope.aggSettings = new AggregationSettings
    $scope.aggSettings.facts = ["date", "sales", "covers", "discounts", "refunds"] #pass these in
    $scope.aggSettings.dimensions = [ "None", "dayPart", "revenueCategory","employee" ] #pass these in
    $scope.aggSettings.groupByFields = []
    $scope.params = {}
    $scope.preferences = retrievePreferences()
    $scope.showAccordians = false
    $scope.fetching = false
    $scope.showAggregateTable = false
    $scope.selectedFact = {}
    $scope.fullSetAggregates = []
    $scope.dataPoints = 100


    $scope.setAggregateOp = (op) ->
        $scope.aggSettings.aggFunction = op

    $scope.setFact = (fact) ->
        $scope.aggSettings.currentFact = fact

    $scope.toggleGrouping = (field) ->
        if field in $scope.aggSettings.groupByFields
            $scope.aggSettings.groupByFields.splice($scope.aggSettings.groupByFields.indexOf(field), 1)
        else
            $scope.aggSettings.groupByFields.push field        
        console.log $scope.aggSettings.groupByFields

    $scope.exportMetricsToCsv = () ->
        csv = exportAsCSV($scope.metrics)
        csvUri = encodeURI(csv)
        $window.open(csvUri)

    $scope.calculateAggregateKvp = (xAxisFunc) ->
        console.log($scope.aggSettings.groupByFields)
        console.log($scope.aggSettings.currentFact)
        aggregates = aggregate($scope.aggSettings.groupByFields, $scope.aggSettings.aggFunction.func, xAxisFunc, $scope.aggSettings.currentFact, $scope.metrics)
        formattedData = []
        for own category, group of aggregates
            formattedData.push {key: category, values: group}
        formattedData

    $scope.calculateFullSetAggregates = ()->
        d3.selectAll("svg > *").remove()
        if $scope.validationFailed() then return
        $scope.showAggregateTable = true

        xFunc = (d) ->
            dataString($scope.aggSettings.groupByFields, d)

        means = aggregate($scope.aggSettings.groupByFields, mean, xFunc, $scope.aggSettings.currentFact, $scope.metrics)
        sums = aggregate($scope.aggSettings.groupByFields, sum, xFunc, $scope.aggSettings.currentFact, $scope.metrics)
        counts = aggregate($scope.aggSettings.groupByFields, count, xFunc, $scope.aggSettings.currentFact, $scope.metrics)
        maximums = aggregate($scope.aggSettings.groupByFields, max, xFunc, $scope.aggSettings.currentFact, $scope.metrics)
        minimums = aggregate($scope.aggSettings.groupByFields, min, xFunc, $scope.aggSettings.currentFact, $scope.metrics)

        table = []
        for k, v of means
            n = {name: k, mean: v[0][1], sum: sums[k][0][1], count: counts[k][0][1], maximum: maximums[k][0][1], minimum: minimums[k][0][1]}
            table.push n
        $scope.fullSetAggregates = table

    $scope.barsByHour = () ->
        console.log ("in the call")
        $scope.showAggregateTable = false
        d3.selectAll("svg > *").remove()
        console.log ("removed old svg")
        #if $scope.validationFailed() then return
        $scope.aggSettings.tab = 2

        hours = (d) ->
            new Date(d.date).getHours()

        formattedData = $scope.calculateAggregateKvp(hours)      
        console.log(formattedData)


        kvpData = []
        for a in formattedData
            n = {key: a.key, values: []}
            for v in a.values
                n["values"].push({x: v[0], y: v[1]})
            kvpData.push(n)

        console.log (kvpData)

        nv.addGraph ->
            # chart = nv.models.multiBarChart()
            #       .transitionDuration(350)
            #       .reduceXTicks(true)  #If 'false', every single x-axis tick label will be rendered.
            #       .rotateLabels(0)      #Angle to rotate x-axis labels.
            #       .showControls(true)   #Allow user to switch between 'Grouped' and 'Stacked' mode.
            #       .groupSpacing(0.1) 
            
            chart = nv.models.multiBarChart()

            console.log("chart created")

            chart.xAxis.tickFormat d3.format(",1f")
            chart.yAxis.tickFormat d3.format(",1f")
            console.log("axis scaled")

            d3.select("#chart svg")
                .datum(kvpData)
                .call(chart)
            nv.utils.windowResize chart.update
            chart


    $scope.barByTime = () ->
        $scope.showAggregateTable = false
        d3.selectAll("svg > *").remove()
        if $scope.validationFailed() then return
        $scope.aggSettings.tab = 4

        tsFunc = (d) ->
            d.date

        formattedData = $scope.calculateAggregateKvp(tsFunc)      
        heightCoefficient = if formattedData.length >= 15 then 5 else 1

        nv.addGraph ->
            chart = nv.models.multiBarChart()
            .x( (d) -> d[0] ).y( (d) -> d[1] ).transitionDuration(350).reduceXTicks(true).rotateLabels(25).groupSpacing(0.01).margin({left: 100, bottom: 60})
            chart.xAxis.tickFormat( (d) ->
                d3.time.format("%x %X")(new Date(d)))
            chart.yAxis.tickFormat d3.format(",.001f")
            d3.select("#chart svg").datum(formattedData).call(chart)
            nv.utils.windowResize chart.update
            chart

    $scope.lineByTimeFocusable = () ->
        $scope.showAggregateTable = false
        d3.selectAll("svg > *").remove()
        if $scope.validationFailed() then return
        $scope.aggSettings.tab = 3
        
        tsFunc = (d) ->
            d.date

        formattedData = $scope.calculateAggregateKvp(tsFunc)

        nv.addGraph ->
            chart = nv.models.lineWithFocusChart().x( (d) ->d[0]).y( (d)-> d[1])
            chart.xAxis.tickFormat( (d) ->
                d3.time.format("%x %X")(new Date(d)))
            chart.yAxis.tickFormat(d3.format(',.1f'))
            chart.y2Axis.tickFormat(d3.format(',.1f'))
            chart.x2Axis.tickFormat( (d) ->
                d3.time.format("%x %X")(new Date(d)))

            d3.select("#chart svg").datum(formattedData).transition().duration(500).call chart
            nv.utils.windowResize chart.update
            chart


    $scope.validationFailed = () ->
        failed = false
        if $scope.aggSettings.groupByFields.length <=0
            alert ("You must group by something!")
            failed = true
        if $scope.aggSettings.aggFunction == {}
            alert ("You must select an aggregate opeartion!")
            failed = true
        if $scope.aggSettings.currentFact == {}
            alert ("You must select a fact!")
            failed = true
        return failed

    $scope.fetchMetrics = (params) ->
        $scope.fetching = true
        $scope.aggSettings.startDate = params.startDate
        $scope.aggSettings.endDate = params.endDate
        $scope.dataPoints = params.dataPoints
        console.log($scope.dataPoints)
        emps = ["Smith", "Josh", "Sonia", "Paraig", "Rachel"]
        category = ["Food", "Beverage", "Goods", "Other"]
        dayPart = ["Breakfast", "Lunch", "Dinner"]



        #r = Math.floor(Math.random() * 3000) + 700
        r = $scope.dataPoints
        sales = []

        for i in  [1 .. r]
            s = Math.floor(Math.random() * 150) + 1
            d = Math.floor(Math.random() * 15)
            r = if s % 17 == 0 then Math.floor(Math.random() * s) else 0
            c = Math.floor(Math.random() * 7) + 1
            emp = emps[s % 5]
            date = new Date(params.startDate.getTime() + (Math.random() * (params.endDate.getTime() - params.startDate.getTime())))
            cat = category[s % 4]
            dPart = dayPart[s % 3]
            hours = Math.floor(Math.random() * 14) + 7
            date.setHours(hours)
            rec = {date: date, dayPart: dPart, sales: s, discount: d, refund: r, covers: c, employee: emp, revenueCategory: cat}
            sales.push(rec)

        sales.sort((l, r) ->
            l.date.getTime() - r.date.getTime()
            )

        $scope.metrics = sales
        console.log($scope.metrics)
        $scope.showAccordians = true
        $scope.fetching = false 
    
    
    #refactor this block into a service
    $scope.saveView = () ->
        $window.localStorage.setItem("View-"+$scope.params.newViewName, JSON.stringify($scope.aggSettings))
        console.log $window.localStorage
        $scope.params.newVewName = ""
        $scope.preferences = retrievePreferences()  

    $scope.loadSavedView = (name) ->
        ops = $scope.configuration.operators
        $scope.aggSettings = JSON.parse($window.localStorage.getItem("View-"+name))
        console.log $scope.aggSettings

        op = ops.filter (o) -> o.name == $scope.aggSettings.aggFunction.name
        $scope.aggSettings.aggFunction = op[0]

        $scope.params.startDate = $scope.aggSettings.startDate
        $scope.params.endDate = $scope.aggSettings.endDate

        console.log $scope.aggSettings
        continuation = {}
        t = $scope.aggSettings.tab
        if t == 1 then continuation = $scope.showSlippage
        if t == 2 then continuation = $scope.barsByHour
        if t == 3 then continuation = $scope.lineByTimeFocusable
        if t == 4 then continuation = $scope.barByTime

        $scope.fetchMetrics($scope.params, continuation)

    # $scope.removeSavedView = (name) ->
    #     console.log "deleting view " + name
    #     $window.localStorage.removeItem("View-" + name)
    #     $scope.preferences = retrievePreferences()  

)

window.angular.module('app', ['latency'])
