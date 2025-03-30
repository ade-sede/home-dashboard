import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: compactRoot
    
    Layout.minimumWidth: 200
    Layout.preferredWidth: 250
    Layout.minimumHeight: 38
    
    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 1
        
        PlasmaComponents.BusyIndicator {
            id: busyIndicator
            Layout.alignment: Qt.AlignHCenter
            visible: plasmoid.rootItem.isLoading
            running: visible
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
        
        Repeater {
            id: legsRepeater
            model: plasmoid.rootItem.legs
            visible: !plasmoid.rootItem.isLoading
            
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 4
                
                Rectangle {
                    width: lineLabel.width + 8
                    height: lineLabel.height + 4
                    radius: 3
                    color: PlasmaCore.Theme.highlightColor
                    
                    PlasmaComponents.Label {
                        id: lineLabel
                        anchors.centerIn: parent
                        text: modelData.line_short_name
                        font.bold: true
                        font.pixelSize: theme.smallestFont.pixelSize - 1
                        color: PlasmaCore.Theme.highlightedTextColor
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: directionLabel.implicitWidth + 8
                    Layout.fillWidth: true
                    height: directionLabel.height + 2
                    color: PlasmaCore.Theme.backgroundColor
                    opacity: 0.5
                    radius: 2
                    border.width: 1
                    border.color: PlasmaCore.Theme.disabledTextColor
                    
                    PlasmaComponents.Label {
                        id: directionLabel
                        anchors.centerIn: parent
                        text: modelData.trip_direction
                        font.italic: true
                        font.pixelSize: theme.smallestFont.pixelSize - 1
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
                          plasmoid.rootItem.formatTime(nextDeparture.departure_time, nextDeparture.delay) : 
                          "--:--"
                    
                    Layout.minimumWidth: 36
                    font.bold: true
                    font.pixelSize: theme.smallestFont.pixelSize - 1
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
            font.pixelSize: theme.smallestFont.pixelSize - 1
        }
    }
    
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
