import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: fullRoot
    
    Layout.minimumWidth: 350
    Layout.preferredWidth: 600
    Layout.minimumHeight: 300
    Layout.preferredHeight: 700
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Header
        Column {
            Layout.fillWidth: true
            spacing: 8
            
            PlasmaExtras.Heading {
                width: parent.width
                level: 2
                text: "Transit Times"
                horizontalAlignment: Text.AlignHCenter
                font.letterSpacing: 1.2
            }
            
            RowLayout {
                width: parent.width
                Item { Layout.fillWidth: true }
                
                PlasmaComponents.Button {
                    icon.name: "view-refresh"
                    text: "Refresh"
                    onClicked: {
                        var rootItem = plasmoid.rootItem
                        if (rootItem && typeof rootItem.forceRefreshCache === "function") {
                            rootItem.forceRefreshCache()
                        }
                    }
                }
                
                PlasmaComponents.Button {
                    icon.name: "configure"
                    onClicked: {
                        plasmoid.action("configure").trigger()
                    }
                }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: PlasmaCore.Theme.disabledTextColor
                opacity: 0.3
            }
        }
        
        // Loading indicator
        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: plasmoid.rootItem.isLoading
            running: visible
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
        }
        
        // No data message
        PlasmaComponents.Label {
            visible: plasmoid.rootItem.legs.length === 0 && !plasmoid.rootItem.isLoading
            text: "No transit data available"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        
        // Legs and estimates
        Repeater {
            id: legsRepeater
            model: plasmoid.rootItem.legs
            visible: !plasmoid.rootItem.isLoading
            
            delegate: Column {
                Layout.fillWidth: true
                spacing: 8
                width: parent.width
                
                // Line header with colored box and styled direction
                RowLayout {
                    width: parent.width
                    spacing: 4
                    
                    // Line number box
                    Rectangle {
                        width: lineLabel.width + 16
                        height: lineLabel.height + 8
                        radius: 4
                        color: PlasmaCore.Theme.highlightColor
                        
                        PlasmaComponents.Label {
                            id: lineLabel
                            anchors.centerIn: parent
                            text: modelData.line_short_name
                            font.bold: true
                            color: PlasmaCore.Theme.highlightedTextColor
                        }
                    }
                    
                    // Direction label
                    RowLayout {
                        spacing: 8
                        
                        PlasmaComponents.Label {
                            text: "Direction:"
                            font.bold: true
                            opacity: 0.7
                        }
                        
                        // Direction value in a subtle box
                        Rectangle {
                            Layout.preferredWidth: directionLabel.implicitWidth + 12
                            height: directionLabel.height + 6
                            color: PlasmaCore.Theme.backgroundColor
                            opacity: 0.5
                            radius: 3
                            border.width: 1
                            border.color: PlasmaCore.Theme.disabledTextColor
                            
                            PlasmaComponents.Label {
                                id: directionLabel
                                anchors.centerIn: parent
                                text: modelData.trip_direction
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }
                        
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
                
                // Create a fixed grid with proper cell alignment
                GridLayout {
                    id: timesGrid
                    width: parent.width
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 12
                    
                    property var legEstimate: plasmoid.rootItem.estimates[modelData.id]
                    property var departures: legEstimate && legEstimate.estimates ? 
                                            legEstimate.estimates : []
                    
                    // Headers with station names
                    Column {
                        Layout.column: 0
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width * 0.5
                        Layout.alignment: Qt.AlignHCenter
                        
                        PlasmaComponents.Label {
                            width: parent.width
                            text: "Departure from:"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        PlasmaComponents.Label {
                            width: parent.width
                            text: modelData.from_stop_name
                            font.italic: true
                            font.underline: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    
                    Column {
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width * 0.5
                        Layout.alignment: Qt.AlignHCenter
                        
                        PlasmaComponents.Label {
                            width: parent.width
                            text: "Arrival at:"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        PlasmaComponents.Label {
                            width: parent.width
                            text: modelData.to_stop_name
                            font.italic: true
                            font.underline: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    
                    // Generate times for each departure
                    Repeater {
                        model: timesGrid.departures
                        
                        delegate: Item {
                            Layout.row: index + 1
                            Layout.column: 0
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            height: depTimesRow.height
                            
                            GridLayout {
                                id: depTimesRow
                                width: parent.width
                                columns: 2
                                columnSpacing: 12
                                
                                PlasmaComponents.Label {
                                    id: departureTime
                                    text: plasmoid.rootItem.formatTime(modelData.departure_time)
                                    color: modelData.delay ? "red" : (index === 0 ? theme.textColor : Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.7))
                                    font.bold: index === 0
                                    font.pointSize: index === 0 ? theme.defaultFont.pointSize : theme.defaultFont.pointSize * 0.9
                                    Layout.column: 0
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: parent.width * 0.5
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                PlasmaComponents.Label {
                                    text: plasmoid.rootItem.formatTime(modelData.arrival_time)
                                    color: index === 0 ? theme.textColor : Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.7)
                                    font.bold: index === 0
                                    font.pointSize: index === 0 ? theme.defaultFont.pointSize : theme.defaultFont.pointSize * 0.9
                                    Layout.column: 1
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: parent.width * 0.5
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // Incidents
                Repeater {
                    model: plasmoid.rootItem.estimates[modelData.id] && 
                           plasmoid.rootItem.estimates[modelData.id].incidents ? 
                           plasmoid.rootItem.estimates[modelData.id].incidents : []
                    
                    delegate: RowLayout {
                        width: parent.width
                        spacing: 8
                        
                        PlasmaComponents.Label {
                            text: "⚠️"
                            font.pointSize: theme.defaultFont.pointSize * 1.2
                        }
                        
                        PlasmaComponents.Label {
                            text: modelData.message
                            color: "orange"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                
                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.disabledTextColor
                    opacity: 0.3
                    visible: index < plasmoid.rootItem.legs.length - 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
    
    // Force update when data changes
    Connections {
        target: plasmoid.rootItem
        function onEstimatesUpdated() {
            legsRepeater.model = null
            legsRepeater.model = plasmoid.rootItem.legs
        }
        function onLegsUpdated() {
            legsRepeater.model = plasmoid.rootItem.legs
        }
    }
}
