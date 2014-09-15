jodaDateToHumanReadable = (jodaDate) ->
    dt = new Date(jodaDate)
    dt.getFullYear()+"-"+(dt.getMonth()+1)+"-"+dt.getDate()

otcRepStatusToHumanReadable= (status) ->
    js = JSON.parse(status)
    js.startDate = jodaDateToHumanReadable(js.startDate)
    js.endDate = jodaDateToHumanReadable(js.endDate)
    js.dateStored = jodaDateToHumanReadable(js.dateStored)
    return js

draggable = () ->
	return {
		restrict: "A"
		link: (scope, element, attributes, ctlr) ->
			element.attr("draggable", true)
			element.bind("dragstart", (e) ->
				e.originalEvent.dataTransfer.setData("text", attributes.itemid))
		}

dropTarget = () ->
	return {
		restrict: "A"
		link: (scope, element, attributes, ctlr) ->
			element.bind("dragover", (e) ->
				e.preventDefault())
			element.bind("drop", (e) ->
				scope.moveToBox(parseInt(e.originalEvent.dataTransfer.getData("text")))
				e.preventDefault())
	}

