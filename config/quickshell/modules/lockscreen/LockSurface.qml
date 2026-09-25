import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.dashboard

Rectangle {
	id: root

	required property LockContext context
	property var shell: null

	function fmtTime(sec) {
		if (!isFinite(sec) || sec < 0)
			sec = 0
		const m = Math.floor(sec / 60)
		const s = Math.floor(sec % 60)
		return m + ":" + (s < 10 ? "0" : "") + s
	}

	readonly property bool active: Window.active
	readonly property color bg: root.shell ? root.shell.barBg : "#101014"
	readonly property color fg: root.shell ? root.shell.barFg : "#f2f2f2"
	readonly property color accent: root.shell ? root.shell.emph(root.shell.barMain, 1.25) : "#9fd4e6"
	readonly property color errorColor: root.shell ? root.shell.accent : "#e06c75"
	readonly property string fontFamily: root.shell ? root.shell.textFont : "sans-serif"
	readonly property string clockFontFamily: root.shell ? root.shell.clockFont : root.fontFamily
	readonly property int innerRadius: (root.shell && root.shell.cornerRadius > 0) ? 18 : 0
	readonly property bool wallLight: root.shell ? root.shell.wallLight : false
	readonly property string wallpaperPath: root.shell ? root.shell.wallpaperPath : ""

	readonly property color tonalContainer: Qt.alpha(root.accent, 0.16)
	readonly property color tonalContainerFocused: Qt.alpha(root.accent, 0.26)
	readonly property color panelBg: Qt.alpha(root.fg, 0.08)
	readonly property color scrim: Qt.alpha(root.wallLight ? "#ffffff" : "#000000", root.wallLight ? 0.28 : 0.42)

	color: bg

	Behavior on color { ColorAnimation { duration: 300 } }

	Image {
		id: bgImage
		anchors.fill: parent
		visible: source !== "" && status === Image.Ready
		source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		cache: true
		smooth: true
	}

	MultiEffect {
		anchors.fill: bgImage
		source: bgImage
		visible: bgImage.visible
		blurEnabled: true
		blur: 1.0
		blurMax: 80
		saturation: -0.1
		brightness: root.wallLight ? 0 : -0.05
	}

	Rectangle {
		anchors.fill: parent
		color: root.scrim

		Behavior on color { ColorAnimation { duration: 300 } }
	}

	SystemClock {
		id: clock
		precision: SystemClock.Seconds
	}

	ColumnLayout {
		id: leftPanel
		anchors.left: parent.left
		anchors.leftMargin: 48
		anchors.verticalCenter: parent.verticalCenter
		width: 240
		visible: root.width > 900
		opacity: root.active ? 1 : 0.55

		Behavior on opacity { NumberAnimation { duration: 220 } }

		DashCard {
			shell: root.shell
			title: "System"
			icon: "\uf2db"
			Layout.fillWidth: true

			StatBar {
				shell: root.shell
				label: "CPU"
				value: root.shell ? root.shell.cpu + "%" : ""
				fraction: root.shell ? root.shell.cpu / 100 : 0
			}

			StatBar {
				shell: root.shell
				label: "Memory"
				value: root.shell ? root.shell.mem + "%" : ""
				fraction: root.shell ? root.shell.mem / 100 : 0
			}

			StatBar {
				shell: root.shell
				label: root.shell && root.shell.netType === "" ? "Offline" : (root.shell && root.shell.netType === "wifi" ? "Wi-Fi" : "Ethernet")
				value: root.shell ? root.shell.netName : ""
			}
		}
	}

	ColumnLayout {
		id: rightPanel
		anchors.right: parent.right
		anchors.rightMargin: 48
		anchors.verticalCenter: parent.verticalCenter
		width: 240
		visible: root.width > 900
		opacity: root.active ? 1 : 0.55

		Behavior on opacity { NumberAnimation { duration: 220 } }

		DashCard {
			shell: root.shell
			title: (root.shell && root.shell.player && root.shell.player.identity) ? root.shell.player.identity : "Media"
			icon: "\uf001"
			Layout.fillWidth: true

			Text {
				visible: !root.shell || root.shell.player === null
				Layout.alignment: Qt.AlignHCenter
				text: "Nothing playing"
				color: Qt.alpha(root.fg, 0.6)
				font.family: root.fontFamily
				font.pixelSize: 12
			}

			RowLayout {
				visible: root.shell && root.shell.player !== null
				Layout.fillWidth: true
				spacing: 10

				Item {
					Layout.preferredWidth: 48
					Layout.preferredHeight: 48
					Layout.alignment: Qt.AlignTop

					Rectangle {
						anchors.fill: parent
						radius: root.innerRadius > 0 ? 8 : 0
						color: root.panelBg
						visible: art.status !== Image.Ready

						Text {
							anchors.centerIn: parent
							text: "\uf001"
							color: Qt.alpha(root.fg, 0.5)
							font.family: root.fontFamily
							font.pixelSize: 16
						}
					}

					Image {
						id: art
						anchors.fill: parent
						source: (root.shell && root.shell.player && root.shell.player.trackArtUrl) ? root.shell.player.trackArtUrl : ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						visible: status === Image.Ready
					}
				}

				ColumnLayout {
					Layout.fillWidth: true
					Layout.alignment: Qt.AlignVCenter
					spacing: 2

					Text {
						Layout.fillWidth: true
						elide: Text.ElideRight
						text: root.shell && root.shell.player ? root.shell.player.trackTitle : ""
						color: root.fg
						font.family: root.fontFamily
						font.pixelSize: 12
						font.bold: true
						textFormat: Text.PlainText
					}

					Text {
						Layout.fillWidth: true
						elide: Text.ElideRight
						text: root.shell && root.shell.player ? root.shell.player.trackArtist : ""
						color: Qt.alpha(root.fg, 0.6)
						font.family: root.fontFamily
						font.pixelSize: 10
						textFormat: Text.PlainText
					}
				}
			}

			RowLayout {
				visible: root.shell && root.shell.player !== null
				Layout.fillWidth: true
				spacing: 6

				Text {
					text: root.shell && root.shell.player ? root.fmtTime(root.shell.player.position) : ""
					color: Qt.alpha(root.fg, 0.55)
					font.family: root.fontFamily
					font.pixelSize: 10
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 4
					Layout.alignment: Qt.AlignVCenter
					radius: root.innerRadius > 0 ? 2 : 0
					color: Qt.alpha(root.fg, 0.15)

					Rectangle {
						width: parent.width * (root.shell && root.shell.player && root.shell.player.length > 0 ? Math.min(1, root.shell.player.position / root.shell.player.length) : 0)
						height: parent.height
						radius: parent.radius
						color: root.accent
					}
				}

				Text {
					text: root.shell && root.shell.player ? root.fmtTime(root.shell.player.length) : ""
					color: Qt.alpha(root.fg, 0.55)
					font.family: root.fontFamily
					font.pixelSize: 10
				}
			}

			RowLayout {
				visible: root.shell && root.shell.player !== null
				Layout.alignment: Qt.AlignHCenter
				spacing: 24

				Text {
					text: "\uf048"
					color: root.fg
					font.family: root.fontFamily
					font.pixelSize: 14

					MouseArea {
						anchors.fill: parent
						anchors.margins: -8
						onClicked: {
							if (root.shell && root.shell.player)
								root.shell.player.previous()
						}
					}
				}

				Text {
					text: root.shell && root.shell.player && root.shell.player.isPlaying ? "\uf04c" : "\uf04b"
					color: root.accent
					font.family: root.fontFamily
					font.pixelSize: 17

					MouseArea {
						anchors.fill: parent
						anchors.margins: -8
						onClicked: {
							if (root.shell && root.shell.player)
								root.shell.player.togglePlaying()
						}
					}
				}

				Text {
					text: "\uf051"
					color: root.fg
					font.family: root.fontFamily
					font.pixelSize: 14

					MouseArea {
						anchors.fill: parent
						anchors.margins: -8
						onClicked: {
							if (root.shell && root.shell.player)
								root.shell.player.next()
						}
					}
				}
			}
		}
	}

	ColumnLayout {
		anchors.centerIn: parent
		width: 340
		spacing: 4
		opacity: root.active ? 1 : 0.55

		Behavior on opacity { NumberAnimation { duration: 220 } }

		Text {
			Layout.alignment: Qt.AlignHCenter
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			text: Qt.formatDateTime(clock.date, "HH:mm")
			color: "#ffffff"
			font.family: root.clockFontFamily
			font.pixelSize: 96
			font.bold: true
			style: Text.Raised
			styleColor: Qt.alpha("#000000", 0.35)
		}

		Text {
			Layout.alignment: Qt.AlignHCenter
			Layout.fillWidth: true
			Layout.bottomMargin: 40
			horizontalAlignment: Text.AlignHCenter
			text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
			color: Qt.alpha("#ffffff", 0.85)
			font.family: root.fontFamily
			font.pixelSize: 15
			font.bold: true
			style: Text.Raised
			styleColor: Qt.alpha("#000000", 0.3)
		}

		Rectangle {
			id: field
			Layout.alignment: Qt.AlignHCenter
			Layout.preferredWidth: 320
			Layout.preferredHeight: 50
			radius: root.innerRadius
			color: passwordBox.activeFocus ? root.tonalContainerFocused : root.tonalContainer
			border.width: 1
			border.color: passwordBox.activeFocus ? root.accent : Qt.alpha(root.accent, 0.25)
			clip: true

			Behavior on color { ColorAnimation { duration: 180 } }
			Behavior on border.color { ColorAnimation { duration: 180 } }

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 16
				anchors.rightMargin: 10
				spacing: 10

				Text {
					Layout.alignment: Qt.AlignVCenter
					text: "\uf023"
					color: passwordBox.activeFocus ? root.accent : Qt.alpha(root.fg, 0.6)
					font.family: root.fontFamily
					font.pixelSize: 15

					Behavior on color { ColorAnimation { duration: 180 } }
				}

				Item {
					Layout.fillWidth: true
					Layout.fillHeight: true
					Layout.alignment: Qt.AlignVCenter

					Text {
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						visible: passwordBox.text === ""
						text: "Enter password"
						color: Qt.alpha(root.fg, 0.4)
						font.family: root.fontFamily
						font.pixelSize: 14
					}

					TextInput {
						id: passwordBox
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						clip: true
						focus: true
						enabled: !root.context.unlockInProgress
						echoMode: TextInput.Password
						inputMethodHints: Qt.ImhSensitiveData
						color: root.fg
						selectionColor: root.accent
						selectedTextColor: root.bg
						font.family: root.fontFamily
						font.pixelSize: 14
						font.bold: true
						verticalAlignment: TextInput.AlignVCenter

						onTextChanged: root.context.currentText = this.text

						onAccepted: root.context.tryUnlock()

						Connections {
							target: root.context

							function onCurrentTextChanged() {
								passwordBox.text = root.context.currentText
							}
						}
					}
				}

				Rectangle {
					id: unlockBtn
					Layout.alignment: Qt.AlignVCenter
					Layout.preferredWidth: 32
					Layout.preferredHeight: 32
					radius: root.innerRadius > 0 ? 9 : 0
					color: unlockArea.pressed ? Qt.darker(root.accent, 1.15) : (unlockArea.containsMouse ? root.accent : Qt.alpha(root.accent, 0.2))
					opacity: (!root.context.unlockInProgress && root.context.currentText !== "") ? 1 : 0.4

					Behavior on color { ColorAnimation { duration: 120 } }
					Behavior on opacity { NumberAnimation { duration: 150 } }

					Text {
						anchors.centerIn: parent
						text: "\uf061"
						color: unlockArea.containsMouse ? root.bg : root.accent
						font.family: root.fontFamily
						font.pixelSize: 13

						Behavior on color { ColorAnimation { duration: 120 } }
					}

					MouseArea {
						id: unlockArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						enabled: !root.context.unlockInProgress && root.context.currentText !== ""
						onClicked: root.context.tryUnlock()
					}
				}
			}
		}

		Item {
			Layout.alignment: Qt.AlignHCenter
			Layout.topMargin: 10
			Layout.preferredWidth: 320
			Layout.preferredHeight: 16

			Text {
				anchors.centerIn: parent
				visible: root.context.unlockInProgress
				text: "Unlocking\u2026"
				color: Qt.alpha("#ffffff", 0.75)
				font.family: root.fontFamily
				font.pixelSize: 12
				font.bold: true
			}

			Text {
				anchors.centerIn: parent
				text: "Incorrect password"
				color: root.errorColor
				font.family: root.fontFamily
				font.pixelSize: 12
				font.bold: true
				opacity: root.context.showFailure ? 1 : 0

				Behavior on opacity { NumberAnimation { duration: 180 } }
			}
		}
	}
}
