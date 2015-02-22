
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
        $scope.showAggregateTable = false
        $scope.showTmap = false
        d3.selectAll("svg > *").remove()
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
            chart = nv.models.multiBarChart()

            chart.xAxis.tickFormat d3.format(",1f")
            chart.yAxis.tickFormat d3.format(",1f")

            d3.select("#chart svg")
                .datum(kvpData)
                .call(chart)
            nv.utils.windowResize chart.update
            chart



    $scope.barsByX = () ->
        $scope.showAggregateTable = false
        $scope.showTmap = false
        d3.selectAll("svg > *").remove()
        #if $scope.validationFailed() then return
        $scope.aggSettings.tab = 2

        hours = (d) ->
            new Date(d.date).getHours()

        formattedData = $scope.calculateAggregateKvp(hours)      
        kvpData = []
        for a in formattedData
            n = {key: a.key, values: []}
            for v in a.values
                n["values"].push({x: v[0], y: v[1]})
            kvpData.push(n)



    $scope.barByTime = () ->
        $scope.showAggregateTable = false
        $scope.showTmap = false
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
        $scope.showTmap = false
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
    
    $scope.makeCatalogTree = () ->
        tree = []
        # tree node looks like {"name", children} or {name, value}
        sites = [{n:"Tatte Third St", m: 17}, 
                {n:"Tatte Broadway", m: 5}, 
                {n:"Tatte Beacon Hill", m: 9},
                {n: "Tatte Outer Kendall", m: 14}, 
                {n:"Tatte Catering", m:  10}]


        r = (n) -> Math.floor(Math.random() * n) + 1
    

        for site in sites
            label = site.n
            multiplier = site.m
            node = {name: label, children: [
                {name: "Food", children: [
                    {name: "Pasteries", children: [
                        {name: "Muffin", value: r(30) * multiplier},
                        {name: "Cookie", value: r(70) * multiplier},
                        {name: "Crossiant", value: r(100) * multiplier},
                        {name: "Bread", value: r(15) * multiplier}
                    ]},
                    {name: "Salads", children: [
                        {name: "Chicken", value: r(45) * multiplier},
                        {name: "Garden", value: r(84) * multiplier},
                        {name: "Steak", value: r(97) * multiplier}
                    ]},
                    {name: "Sandwiches", children: [
                        {name: "PB & J", value: r(57) * multiplier},
                        {name: "Tuna", value: r(74) * multiplier},
                        {name: "Grilled Cheese", value: r(119) * multiplier},
                        {name: "Meatball Sub", value: r(159) * multiplier},
                        {name: "Chicken", value: r(103) * multiplier},
                        {name: "Reuben", value: r(133) * multiplier}
                    ]},
                ]},
                {name: "Beverages", children: [
                    {name: "Coffees", children: [
                        {name: "Drip", value: r(15) * multiplier},
                        {name: "Americano", value: r(22) * multiplier},
                        {name: "Cappucino", value: r(31) * multiplier},
                        {name: "Espresso", value: r(46) * multiplier},
                        {name: "Latte", value: r(18) * multiplier}
                    ]},
                    {name: "Sodas", children: [
                        {name: "San Pelegrino", value: r(33) * multiplier},
                        {name: "Coke", value: r(11) * multiplier},
                        {name: "Pepsi", value: r(11) * multiplier}
                    ]},
                    {name: "Cocktails", children: [
                        {name: "A", value: r(10) * multiplier},
                        {name: "B", value: r(20) * multiplier},
                        {name: "C", value: r(30) * multiplier},
                        {name: "D", value: r(40) * multiplier},
                        {name: "E", value: r(50) * multiplier},
                        {name: "F", value: r(60) * multiplier}
                    ]},
                ]},
                {name: "Goods", children: [
                    {name: "Books", children: [
                        {name: "Cookbook 1", value: r(19) * multiplier},
                        {name: "Cookbook 2", value: r(29) * multiplier}
                    ]},
                    {name: "Clothes", children: [
                        {name: "Apron", value: r(7) * multiplier},
                        {name: "Hat", value: r(7) * multiplier},
                        {name: "Tee", value: r(7) * multiplier},
                        {name: "Sweatshirt", value: r(7) * multiplier}
                    ]}
                ]},
                {name: "Other", children: [
                    {name: "Gift Cards", children: [
                        {name: "Tatte Brand", value: r(70) * multiplier},
                        {name: "Processor Brand", value: r(15) * multiplier},
                        {name: "Monopoly Money", value: 9}
                    ]}
                ]}
            ]}
            tree.push(node)
 
        tatte = {name: "Tatte", children: tree}
        return tatte
        
        

    $scope.treeMap = () ->
        $scope.showAggregateTable = false
        d3.selectAll("svg > *").remove()
        $scope.aggSettings.tab = 5
        tree = $scope.makeCatalogTree()

        margin = {top: 20, right: 0, bottom:0, left:0}
        width = 960
        height = 500 - margin.top - margin.bottom
        formatNumber = d3.format(",d")
        transitioning = null

        x = d3.scale.linear().domain([0, width]).range([0, width])
        y = d3.scale.linear().domain([0, height]).range([0, height])

        tMap = d3.layout.treemap()
            .children((d, depth) -> if depth then  null else d._children)
            .sort((l, r) -> l.value - r.value)
            .ratio(height / width * 0.5 * (1 + Math.sqrt(5)))
            .round(false)

        svg = d3.select("#chart svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.bottom + margin.top)
            .style("background", "#ddd")
            .style("margin-left", -margin.left + "px")
            .style("margin.right", -margin.right + "px")
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")")
            .style("shape-rendering", "crispEdges")

        grandparent = svg.append("g").attr("class", "grandparent")
        grandparent.append("rect").attr("y", -margin.top)
        .attr("width", width)
        .attr("height", margin.top)

        grandparent.append("text").attr("y", 6 - margin.top).attr("x", 6).attr("dy", ".75em")

        initialize = (data) ->
            data.x = 0
            data.y = 0
            data.dx = width
            data.dy = height
            data.depth = 0

        # Recursively walk the data & aggregate the leaf node values
        accumulate = (data) ->
            if data._children = data.children 
            then data.value = `data.children.reduce(function(p, v) { return p + accumulate(v); }, 0)`
            else data.value

        # Recursively walk the children & set proportional layouts so we can preserve good ratios
        layout = (data) ->
            if data._children 
                tMap.nodes({_children: data._children})
                for child in data._children
                    child.x = data.x + child.x * data.dx
                    child.y = data.y + child.y * data.dy
                    child.dx *= data.dx 
                    child.dy *= data.dy
                    child.parent = data
                    layout(child)

        display = (data) ->
            grandparent.datum(data.parent)
            .on("click", (d, i) -> 
                transition(d))
            .select("text").text(name(data))

            g1 = svg.insert("g", ".grandparent")
            .datum(data)
            .attr("class", "depth")

            g = g1.selectAll("g").data(data._children)
            .enter().append("g")

            g.filter((d) -> d._children).classed("children", true)
            .on("click", (d, i) ->
                transition(d))

            g.selectAll(".child").data((d) -> d._children || [d])
            .enter().append("rect").attr("class", "child").call(rect)

            g.append("rect").attr("class", "parent").call(rect)
            .append("title").text((d) -> formatNumber(d.value))

            g.append("text").attr("dy", ".75em")
            .text((d) -> d.name + ":  $"+ d.value).call(text)

            transition = (d) ->
                if transitioning or !d 
                    return
                else
                    transitioning = true
                    g2 = display(d)
                    t1 = g1.transition().duration(750)
                    t2 = g2.transition().duration(750)
                    x.domain([d.x, d.x + d.dx])
                    y.domain([d.y, d.y + d.dy])
                    svg.style("shape-rendering", null)
                    svg.selectAll(".depth").sort((l, r) -> l.depth - r.depth)
                    g2.selectAll("text").style("fill-opacity", 0)

                    t1.selectAll("text").call(text).style("fill-opacity", 0)
                    t2.selectAll("text").call(text).style("fill-opacity", 1)
                    t1.selectAll("rect").call(rect)
                    t2.selectAll("rect").call(rect)

                    t1.remove().each("end", () ->
                        svg.style("shape-rendering", "crispEdges")
                        transitioning = false)

            return g

        text = (txt) ->
            txt.attr("x", (d) -> x(d.x) + 6).attr("y", (d) -> y(d.y) + 6)

        rect = (rct) ->
            rct.attr("x", (d) -> x(d.x))
            .attr("y", (d) -> y(d.y))
            .attr("width", (d) -> x(d.x + d.dx) - x(d.x))
            .attr("height", (d) -> y(d.y + d.dy) - y(d.y))

        name = (d) -> 
            if d.parent 
            then name(d.parent) + "." + d.name 
            else d.name
    
        initialize(tree)
        accumulate(tree)
        layout(tree)
        display(tree)

        
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
