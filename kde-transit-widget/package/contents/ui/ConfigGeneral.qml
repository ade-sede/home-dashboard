import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: childrenRect.width
    height: childrenRect.height
    
    property alias cfg_serverUrl: serverUrlField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property string cfg_timeFormat: "24h"
    
    ColumnLayout {
        width: parent.width
        spacing: 10
        
        Label { 
            text: "Server Settings"
            font.bold: true
            font.pixelSize: 14
        }
        
        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Layout.fillWidth: true
            
            Label { text: "Server URL:" }
            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: "https://home-dashboard.ade-sede.com"
            }
            
            Label { text: "Username:" }
            TextField {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: "Enter username"
            }
            
            Label { text: "Password:" }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Enter password"
                echoMode: TextInput.Password
            }
        }
        
        Item { height: 20 }
        
        Label { 
            text: "Display Options"
            font.bold: true
            font.pixelSize: 14 
        }
        
        ColumnLayout {
            spacing: 5
            
            RadioButton {
                id: format24h
                text: "24-hour time format (14:30)"
                checked: cfg_timeFormat === "24h"
                onCheckedChanged: {
                    if (checked) {
                        cfg_timeFormat = "24h"
                    }
                }
            }
            
            RadioButton {
                id: format12h
                text: "12-hour time format (2:30 PM)"
                checked: cfg_timeFormat === "12h"
                onCheckedChanged: {
                    if (checked) {
                        cfg_timeFormat = "12h"
                    }
                }
            }
        }
    }
}
