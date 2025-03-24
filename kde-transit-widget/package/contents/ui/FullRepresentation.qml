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
        RowLayout {
            Layout.fillWidth: true
            
            PlasmaExtras.Heading {
                level: 2
                text: "Transit Times"
            }
            
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
                spacing: 4
                width: parent.width
                
                // Leg header
                RowLayout {
                    width: parent.width
                    spacing: 4
                    
                    PlasmaComponents.Label {
                        text: modelData.line_short_name
                        font.bold: true
                        font.pixelSize: theme.defaultFont.pixelSize + 2
                    }
                    
                    PlasmaComponents.Label {
                        text: modelData.trip_direction
                        font.pixelSize: theme.defaultFont.pixelSize
                        elide: Text.ElideRight
                    }
                }
                
                // From - To
                RowLayout {
                    width: parent.width
                    spacing: 4
                    
                    PlasmaComponents.Label {
                        text: modelData.from_stop_name
                        font.pixelSize: theme.smallestFont.pixelSize
                    }
                    
                    PlasmaComponents.Label {
                        text: "→"
                        font.pixelSize: theme.smallestFont.pixelSize
                    }
                    
                    PlasmaComponents.Label {
                        text: modelData.to_stop_name
                        font.pixelSize: theme.smallestFont.pixelSize
                    }
                }
                
                // Next departures
                GridLayout {
                    width: parent.width
                    columns: 3
                    rowSpacing: 4
                    columnSpacing: 8
                    
                    property var legEstimate: plasmoid.rootItem.estimates[modelData.id]
                    property var departures: legEstimate && legEstimate.estimates ? 
                                           legEstimate.estimates : []
                    
                    // Header
                    PlasmaComponents.Label {
                        text: "Departure"
                        font.bold: true
                        Layout.preferredWidth: 80
                        Layout.column: 0
                    }
                    
                    PlasmaComponents.Label {
                        text: "Arrival"
                        font.bold: true
                        Layout.preferredWidth: 80
                        Layout.column: 1
                    }
                    
                    PlasmaComponents.Label {
                        text: "Status"
                        font.bold: true
                        Layout.column: 2
                        Layout.fillWidth: true
                    }
                    
                    // Estimates
                    Repeater {
                        id: departuresRepeater
                        model: parent.departures
                        
                        delegate: Item {
                            Layout.row: index + 1
                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            height: departureRowLayout.height
                            
                            GridLayout {
                                id: departureRowLayout
                                width: parent.width
                                columns: 3
                                
                                PlasmaComponents.Label {
                                    text: plasmoid.rootItem.formatTime(modelData.departure_time)
                                    color: modelData.delay ? "red" : theme.textColor
                                    Layout.preferredWidth: 80
                                    Layout.column: 0
                                }
                                
                                PlasmaComponents.Label {
                                    text: plasmoid.rootItem.formatTime(modelData.arrival_time)
                                    Layout.preferredWidth: 80
                                    Layout.column: 1
                                }
                                
                                PlasmaComponents.Label {
                                    text: modelData.delay ? "Delayed: " + modelData.delay + " min" : "On time"
                                    color: modelData.delay ? "red" : "green"
                                    Layout.column: 2
                                    Layout.fillWidth: true
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
                    
                    delegate: PlasmaComponents.Label {
                        width: parent.width
                        text: "⚠️ " + modelData.message
                        color: "orange"
                        wrapMode: Text.WordWrap
                    }
                }
                
                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.disabledTextColor
                    opacity: 0.3
                    visible: index < plasmoid.rootItem.legs.length - 1
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
