import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root
    
    property var legs: []
    property var estimates: ({})
    property bool isLoading: false
    
    signal legsUpdated()
    signal estimatesUpdated()
    
    property string serverUrl: plasmoid.configuration.serverUrl
    property string username: plasmoid.configuration.username
    property string password: plasmoid.configuration.password
    property string timeFormat: plasmoid.configuration.timeFormat
    Plasmoid.compactRepresentation: CompactRepresentation {}
    Plasmoid.fullRepresentation: FullRepresentation {}
    
    function forceRefreshCache() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                fetchLegs()
            }
        }
        
        xhr.open("POST", serverUrl + "/api/trips/force_refresh")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(username + ":" + password))
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({}))
    }
    
    function fetchLegs() {
        isLoading = true
        
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    legs = data.legs
                    legsUpdated()
                    
                    for (var i = 0; i < legs.length; i++) {
                        fetchEstimates(legs[i].id)
                    }
                } else {
                    console.log("Error fetching legs: " + xhr.status)
                    isLoading = false
                }
            }
        }
        
        xhr.open("GET", serverUrl + "/api/trips/")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(username + ":" + password))
        xhr.send()
    }
    
    function fetchEstimates(legId) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    estimates[legId] = data
                    estimatesUpdated()
                } else {
                    console.log("Error fetching estimates for leg " + legId + ": " + xhr.status)
                }
                
                var allLoaded = true
                for (var i = 0; i < legs.length; i++) {
                    if (!estimates[legs[i].id]) {
                        allLoaded = false
                        break
                    }
                }
                
                if (allLoaded) {
                    isLoading = false
                    updateNextRefreshTime()
                }
            }
        }
        
        xhr.open("GET", serverUrl + "/api/trips/" + legId + "/next")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(username + ":" + password))
        xhr.send()
    }
    
    property var nextRefreshTime: new Date()
    
    Timer {
        id: refreshTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: checkRefresh()
    }
    
    function updateNextRefreshTime() {
        var earliestTime = null
        
        for (var legId in estimates) {
            var legEstimates = estimates[legId].estimates
            if (legEstimates && legEstimates.length > 0) {
                var departureTime = new Date(legEstimates[0].departure_time)
                
                if (earliestTime === null || departureTime < earliestTime) {
                    earliestTime = departureTime
                }
            }
        }
        
        if (earliestTime !== null) {
            nextRefreshTime = earliestTime
        } else {
            var defaultTime = new Date()
            defaultTime.setMinutes(defaultTime.getMinutes() + 5)
            nextRefreshTime = defaultTime
        }
    }
    
    function checkRefresh() {
        var currentTime = new Date()
        if (currentTime >= nextRefreshTime) {
            fetchLegs()
        }
    }
    
    function formatTime(timeString, delaySeconds) {
        var date = new Date(timeString)
        
        if (delaySeconds) {
            date = new Date(date.getTime() - (delaySeconds * 1000))
        }
        
        if (timeFormat === "24h") {
            return date.getHours() + ":" + 
                   (date.getMinutes() < 10 ? "0" : "") + date.getMinutes()
        } else {
            var hours = date.getHours()
            var ampm = hours >= 12 ? "PM" : "AM"
            hours = hours % 12
            hours = hours ? hours : 12
            return hours + ":" + 
                   (date.getMinutes() < 10 ? "0" : "") + date.getMinutes() + 
                   " " + ampm
        }
    }
    
    function formatTimeWithDelay(timeString, delaySeconds) {
        var formattedTime = formatTime(timeString, delaySeconds)
        if (delaySeconds) {
            formattedTime += " (-" + formatDelayMinutes(delaySeconds) + ")"
        }
        return formattedTime
    }
    
    function formatDelayMinutes(delaySeconds) {
        var minutes = Math.floor(delaySeconds / 60)
        return minutes + (minutes === 1 ? " min" : " mins")
    }
    
    Component.onCompleted: {
        fetchLegs()
    }
    
    Connections {
        target: plasmoid.configuration
        function onServerUrlChanged() { fetchLegs() }
        function onUsernameChanged() { fetchLegs() }
        function onPasswordChanged() { fetchLegs() }
    }
}
