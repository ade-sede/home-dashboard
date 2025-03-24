import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: compactRoot
    
    Layout.minimumWidth: 200
    Layout.preferredWidth: 250
    Layout.minimumHeight: 48
    
    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2
        
        // Show loading indicator when fetching data
        PlasmaComponents.BusyIndicator {
            id: busyIndicator
            Layout.alignment: Qt.AlignHCenter
            visible: plasmoid.rootItem.isLoading
            running: visible
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
        }
        
        // Show each leg with its next departure
        Repeater {
            id: legsRepeater
            model: plasmoid.rootItem.legs
            visible: !plasmoid.rootItem.isLoading
            
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 4
                
                PlasmaComponents.Label {
                    text: modelData.line_short_name
                    font.bold: true
                    font.pixelSize: theme.smallestFont.pixelSize
                }
                
                PlasmaComponents.Label {
                    text: "→"
                    font.pixelSize: theme.smallestFont.pixelSize
                }
                
                PlasmaComponents.Label {
                    property var legEstimate: plasmoid.rootItem.estimates[modelData.id]
                    property var nextDeparture: legEstimate && legEstimate.estimates && 
                                               legEstimate.estimates.length > 0 ? 
                                               legEstimate.estimates[0] : null
                    
                    text: nextDeparture ? 
                          plasmoid.rootItem.formatTime(nextDeparture.departure_time) : 
                          "--:--"
                    
                    font.pixelSize: theme.smallestFont.pixelSize
                    color: nextDeparture && nextDeparture.delay ? "red" : theme.textColor
                }
                
                PlasmaComponents.Label {
                    text: modelData.trip_direction
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font.pixelSize: theme.smallestFont.pixelSize
                }
            }
        }
        
        PlasmaComponents.Label {
            visible: plasmoid.rootItem.legs.length === 0 && !plasmoid.rootItem.isLoading
            text: "No transit data available"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
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
