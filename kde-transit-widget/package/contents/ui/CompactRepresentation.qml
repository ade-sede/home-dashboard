import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: compactRoot
    
    Layout.minimumWidth: 200
    Layout.preferredWidth: 250
    Layout.minimumHeight: 38  // Reduced from 48
    
    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1  // Reduced from 2
        spacing: 1  // Reduced from 2
        
        // Show loading indicator when fetching data
        PlasmaComponents.BusyIndicator {
            id: busyIndicator
            Layout.alignment: Qt.AlignHCenter
            visible: plasmoid.rootItem.isLoading
            running: visible
            Layout.preferredWidth: 16  // Smaller indicator
            Layout.preferredHeight: 16  // Smaller indicator
        }
        
        // Show each leg with its next departure
        Repeater {
            id: legsRepeater
            model: plasmoid.rootItem.legs
            visible: !plasmoid.rootItem.isLoading
            
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 4
                
                // Line number box
                Rectangle {
                    width: lineLabel.width + 8  // Reduced padding
                    height: lineLabel.height + 4  // Reduced height
                    radius: 3  // Smaller radius
                    color: PlasmaCore.Theme.highlightColor
                    
                    PlasmaComponents.Label {
                        id: lineLabel
                        anchors.centerIn: parent
                        text: modelData.line_short_name
                        font.bold: true
                        font.pixelSize: theme.smallestFont.pixelSize - 1  // Smaller font
                        color: PlasmaCore.Theme.highlightedTextColor
                    }
                }
                
                // Direction in a subtle box
                Rectangle {
                    Layout.preferredWidth: directionLabel.implicitWidth + 8  // Reduced padding
                    Layout.fillWidth: true
                    height: directionLabel.height + 2  // Reduced height
                    color: PlasmaCore.Theme.backgroundColor
                    opacity: 0.5
                    radius: 2  // Smaller radius
                    border.width: 1
                    border.color: PlasmaCore.Theme.disabledTextColor
                    
                    PlasmaComponents.Label {
                        id: directionLabel
                        anchors.centerIn: parent
                        text: modelData.trip_direction
                        font.italic: true
                        font.pixelSize: theme.smallestFont.pixelSize - 1  // Smaller font
                        elide: Text.ElideRight
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignLeft
                    }
                }
                
                PlasmaComponents.Label {
                    property var legEstimate: plasmoid.rootItem.estimates[modelData.id]
                    property var nextDeparture: legEstimate && legEstimate.estimates && 
                                              legEstimate.estimates.length > 0 ? 
                                              legEstimate.estimates[0] : null
                    
                    text: nextDeparture ? 
                          plasmoid.rootItem.formatTime(nextDeparture.departure_time) : 
                          "--:--"
                    
                    Layout.minimumWidth: 36
                    font.bold: true
                    font.pixelSize: theme.smallestFont.pixelSize - 1  // Smaller font
                    color: nextDeparture && nextDeparture.delay ? "red" : theme.textColor
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
        
        PlasmaComponents.Label {
            visible: plasmoid.rootItem.legs.length === 0 && !plasmoid.rootItem.isLoading
            text: "No transit data"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            font.pixelSize: theme.smallestFont.pixelSize - 1  // Smaller font
        }
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
