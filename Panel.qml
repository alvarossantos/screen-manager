import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var mainInstance: pluginApi?.mainInstance

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 450 * Style.uiScaleRatio
  property real contentPreferredHeight: 400 * Style.uiScaleRatio

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    Flickable {
      id: flickable
      anchors.fill: parent
      anchors.margins: Style.marginL
      contentHeight: contentLayout.implicitHeight
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: contentLayout
        width: flickable.width
        spacing: Style.marginM

        // Título + Botão carregar
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeL
            font.weight: Font.DemiBold
            color: Color.mOnSurface
          }

          NButton {
            text: pluginApi?.tr("panel.actions.refresh")
            icon: "refresh"
            onClicked: {
              mainInstance?.refreshOutputs();
            }
          }
        }

        // Lista de monitores
        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.monitors.label")
          pointSize: Style.fontSizeM
          font.weight: Font.DemiBold
          color: Color.mOnSurface
          Layout.topMargin: Style.marginS
        }

        Repeater {
          model: mainInstance?.outputNames ?? []

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120 * Style.uiScaleRatio
            color: Color.mSurfaceVariant
            radius: Style.radiusM

            property var outputData: mainInstance?.outputs[modelData] ?? ({})

            ColumnLayout {
              anchors {
                fill: parent
                margins: Style.marginM
              }
              spacing: Style.marginXS

              // Cabeçalho do monitor
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  Layout.fillWidth: true
                  text: modelData
                  pointSize: Style.fontSizeM
                  font.weight: Font.DemiBold
                  color: Color.mOnSurface
                }

                NText {
                  text: outputData.isOn ? pluginApi?.tr("panel.status.enabled") : pluginApi?.tr("panel.status.disabled")
                  pointSize: Style.fontSizeS
                  color: outputData.isOn ? Color.mPrimary : Color.mError
                }
              }

              // Informações do monitor
              NText {
                Layout.fillWidth: true
                text: (outputData.make || "") + " " + (outputData.model || "")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }

              // Modo atual
              NText {
                Layout.fillWidth: true
                text: outputData.currentModeStr || pluginApi?.tr("panel.mode.unknown")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
              }

              // Botões de ação
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                  Layout.fillWidth: true
                  text: outputData.isOn ? pluginApi?.tr("panel.actions.disable") : pluginApi?.tr("panel.actions.enable")
                  icon: outputData.isOn ? "device-desktop-off" : "device-desktop"
                  backgroundColor: outputData.isOn ? Color.mError : Color.mPrimary
                  textColor: outputData.isOn ? Color.mOnError : Color.mOnPrimary
                  enabled: outputData.isOn
                           ? (mainInstance?.activeOutputCount ?? 0) > 1
                           : true
                  onClicked: {
                    mainInstance?.setOutputOn(modelData, !outputData.isOn);
                    Qt.callLater(() => mainInstance?.refreshOutputs());
                  }
                }

                NButton {
                  Layout.fillWidth: true
                  property bool isMirroringThis: (mainInstance?.mirroringActive ?? false) && (mainInstance?.mirrorSource ?? "") === modelData
                  text: isMirroringThis
                    ? pluginApi?.tr("panel.actions.stopMirror")
                    : pluginApi?.tr("panel.actions.mirror")
                  icon: isMirroringThis ? "screen-share-off" : "screen-share"
                  backgroundColor: isMirroringThis ? Color.mError : Color.mPrimary
                  textColor: isMirroringThis ? Color.mOnError : Color.mOnPrimary
                  enabled: outputData.isOn && (mainInstance?.outputCount ?? 0) >= 2
                            && (!(isMirroringThis === false && (mainInstance?.mirroringActive ?? false)))
                  onClicked: {
                    if (isMirroringThis) {
                      mainInstance?.stopMirror();
                    } else {
                      const outputs = mainInstance?.outputNames ?? [];
                      let other = "";
                      for (let i = 0; i < outputs.length; i++) {
                        if (outputs[i] !== modelData) {
                          other = outputs[i];
                          break;
                        }
                      }
                      if (other) {
                        mainInstance?.startMirror(modelData, other);
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Mensagem quando não há monitores
        NText {
          Layout.fillWidth: true
          visible: (mainInstance?.outputCount ?? 0) === 0
          text: pluginApi?.tr("panel.noMonitors")
          pointSize: Style.fontSizeS
          color: Color.mError
          wrapMode: Text.WordWrap
        }

        // Mensagem de erro
        NText {
          Layout.fillWidth: true
          visible: (mainInstance?.lastError ?? "") !== ""
          text: mainInstance?.lastError ?? ""
          pointSize: Style.fontSizeS
          color: Color.mError
          wrapMode: Text.WordWrap
        }

        // Aviso de trava: última tela ativa
        NText {
          Layout.fillWidth: true
          visible: (mainInstance?.activeOutputCount ?? 0) === 1 && (mainInstance?.outputCount ?? 0) > 1
          text: pluginApi?.tr("panel.lockWarning")
          pointSize: Style.fontSizeS
          color: Color.mPrimary
          wrapMode: Text.WordWrap
        }

        // Botão de ação rápida
        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.actions.enableAll")
          icon: "device-desktop-plus"
          enabled: (mainInstance?.outputCount ?? 0) >= 2
          Layout.topMargin: Style.marginM
          onClicked: {
            mainInstance?.enableAllOutputs();
          }
        }
      }
    }
  }
}