import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: Commons.I18n.t("lock.enterPassword")
  readonly property int fieldWidth: 320
  readonly property int fieldHeight: 48
  readonly property int outlineThickness: 1
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0


  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  readonly property color ink: "#ffffff"
  readonly property color accent: Commons.Color.accent
  readonly property color errorInk: Commons.Color.lock.textError
  readonly property string home: Quickshell.env("HOME")
  readonly property string user: Quickshell.env("USER") || ""
  // the first of these that loads is the picture: the usual places a desktop keeps a user's face
  readonly property var faces: [home + "/.face", home + "/.face.icon", "/var/lib/AccountsService/icons/" + user]
  property int faceTried: 0
  property string displayName: user.length ? user.charAt(0).toUpperCase() + user.slice(1) : ""
  property date now: new Date()

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  // The field loses focus while a password is checked (it is disabled then),
  // and forcing focus onto it would not stick until the check ends.
  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onFailedAttemptsChanged: if (failedAttempts > 0) shake.restart()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // A VT switch, which the NVIDIA driver forces around every suspend, takes the
  // keyboard away and Qt drops the field's focus with it. Nothing gives it back
  // when the keyboard returns, so typing went nowhere until the field was clicked.
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      // Decode only once sized, at the lock's own size: an unsized first
      // request decoded the file at its native resolution, then again once
      // sized. That size is what the lock service keeps decoded ahead of the
      // lock, so the first frame has the wallpaper.
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 0.5
      blurMax: 48
      blurMultiplier: 1.0
      contrast: -0.04
    }

    // darker where the clock and the password sit, so white text reads on any wallpaper
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.01, 0.05, 0.5) }
        GradientStop { position: 0.45; color: Qt.rgba(0.01, 0.01, 0.05, 0.12) }
        GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.01, 0.05, 0.55) }
      }
    }

    // a wide, faint band of light that takes its time crossing the screen
    Rectangle {
      id: sheen
      width: parent.width * 0.5
      height: parent.height * 2.2
      y: -parent.height * 0.6
      rotation: 18
      opacity: 0.1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: root.ink }
        GradientStop { position: 1.0; color: "transparent" }
      }
      NumberAnimation on x { from: -sheen.width; to: root.width; duration: 16000; loops: Animation.Infinite }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Timer {
      interval: 1000
      repeat: true
      running: true
      triggeredOnStart: true
      onTriggered: root.now = new Date()
    }

    Process {
      running: true
      command: ["getent", "passwd", root.user]
      stdout: StdioCollector {
        onStreamFinished: {
          var name = String(text).split(":")[4] || ""
          name = name.split(",")[0].trim().split(" ")[0]
          if (name.length) root.displayName = name
        }
      }
    }

    Column {
      id: clock

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Math.round(parent.height * 0.075) + intro.lift
      opacity: intro.shown
      spacing: -6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.locale(Commons.I18n.formatLocale).toString(root.now, "dddd, MMMM d")
        color: root.ink
        opacity: 0.88
        font.family: "Adwaita Sans"
        font.pixelSize: Math.round(root.height * 0.036)
        font.weight: Font.Medium
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatTime(root.now, "HH:mm")
        color: root.ink
        font.family: "Adwaita Sans"
        font.pixelSize: Math.round(root.height * 0.091)
        font.weight: Font.Light
        font.letterSpacing: -2
      }
    }

    // the screen comes up in two beats: the clock first, then you and the field
    QtObject {
      id: intro
      property real shown: 0
      property real lift: 14
      property real late: 0
    }

    ParallelAnimation {
      id: arrive
      NumberAnimation { target: intro; property: "shown"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
      NumberAnimation { target: intro; property: "lift"; from: 14; to: 0; duration: 520; easing.type: Easing.OutCubic }
      SequentialAnimation {
        PropertyAction { target: intro; property: "late"; value: 0 }
        PauseAnimation { duration: 180 }
        NumberAnimation { target: intro; property: "late"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }
      }
    }

    Component.onCompleted: arrive.start()

    Column {
      id: who

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: 16
      opacity: intro.late
      spacing: 10

      ClippingRectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 68
        height: 68
        radius: 34
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 2
        border.color: Qt.rgba(1, 1, 1, 0.6)

        Text {
          anchors.centerIn: parent
          visible: face.status !== Image.Ready
          textFormat: Text.PlainText
          text: root.displayName.charAt(0)
          color: root.ink
          font.family: "Adwaita Sans"
          font.pixelSize: 30
          font.weight: Font.DemiBold
        }

        Image {
          id: face
          anchors.fill: parent
          source: root.faceTried < root.faces.length ? "file://" + root.faces[root.faceTried] : ""
          sourceSize: Qt.size(136, 136)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          onStatusChanged: if (status === Image.Error) root.faceTried += 1
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: root.displayName
        color: root.ink
        font.family: "Adwaita Sans"
        font.pixelSize: 19
        font.weight: Font.DemiBold
      }
    }

    // soft light behind the field that breathes, red after a wrong password
    Rectangle {
      id: halo

      anchors.centerIn: inputField
      width: inputField.width + 26
      height: inputField.height + 26
      radius: height / 2
      color: root.errorState ? root.errorInk : root.accent
      opacity: 0.28 * intro.late
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        autoPaddingEnabled: true
      }

      SequentialAnimation on scale {
        loops: Animation.Infinite
        NumberAnimation { from: 0.96; to: 1.07; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.07; to: 0.96; duration: 2200; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      id: inputField

      // the input below was written against a bordered surface, these keep its margins working
      readonly property int borderTop: root.outlineThickness
      readonly property int borderRight: root.outlineThickness
      readonly property int borderBottom: root.outlineThickness
      readonly property int borderLeft: root.outlineThickness

      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(parent.height * 0.14)
      opacity: intro.late
      color: Qt.rgba(1, 1, 1, 0.14)
      border.width: root.outlineThickness
      border.color: root.errorState ? root.errorInk : Qt.rgba(1, 1, 1, 0.32)
      radius: height / 2
      transform: Translate { id: nudge }

      SequentialAnimation {
        id: shake
        NumberAnimation { target: nudge; property: "x"; to: -14; duration: 55 }
        NumberAnimation { target: nudge; property: "x"; to: 12; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: -8; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: 5; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
      }

      // one dot per character, each popping in as it is typed; they squeeze together
      // once the password outgrows the field
      Row {
        id: dots

        readonly property int count: passwordInput.text.length
        readonly property real room: passwordInput.width - 8
        readonly property real size: count > 0 ? Math.max(3, Math.min(10, room / (count * 1.8))) : 10

        anchors.centerIn: passwordInput
        spacing: size * 0.8

        Repeater {
          model: dots.count

          Rectangle {
            width: dots.size
            height: dots.size
            radius: dots.size / 2
            color: root.ink
            scale: 0
            Component.onCompleted: pop.start()
            NumberAnimation on scale { id: pop; running: false; from: 0; to: 1; duration: 150; easing.type: Easing.OutBack }
          }
        }
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: false
        // the dots are the feedback, a caret next to invisible text would only wander
        cursorDelegate: Item {}

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.top: parent.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth * 2
        text: root.authenticatingPassword ? Commons.I18n.t("lock.checking") : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Commons.Color.lock.text : (root.failureMessage.length > 0 ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
        font.family: "Adwaita Sans"
        font.pixelSize: 15
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      // A reader the shell cannot reach crosses out rather than disappears, so
      // it stops inviting touches that can never unlock.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
        color: root.fingerprintUnavailable ? Commons.Color.lock.textError : Commons.Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    // The crossed-out icon has no meaning to a user who has never seen it — it
    // is not intuitive that it signals a broken reader — so the words carry the
    // explanation and the icon only reinforces it.
    Text {
      objectName: "fingerprintUnavailableNotice"
      textFormat: Text.PlainText
      anchors.top: inputField.bottom
      anchors.topMargin: 44
      anchors.horizontalCenter: inputField.horizontalCenter
      visible: root.fingerprintConfigured && root.fingerprintUnavailable
      text: Commons.I18n.t("lock.fingerprintUnavailable")
      color: Commons.Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
