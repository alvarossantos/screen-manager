import QtQuick
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null
  property string lastError: ""
  property var outputs: ({})
  property var outputNames: []
  property int outputCount: 0
  property int activeOutputCount: 0
  property string focusedOutput: ""
  property string pluginDir: pluginApi?.pluginDir ?? ""

  // Estado do espelhamento
  property bool mirroringActive: mirrorProcess.running
  property string mirrorSource: ""
  property string mirrorDestination: ""
  property bool mirrorStopRequested: false

  // Trava: retorna true se pode desligar o output (há mais de 1 tela ativa)
  function canDisable(outputName) {
    // Se o output já está desligado, permitir (não faz mal)
    if (root.outputs[outputName] && !root.outputs[outputName].isOn) {
      return true;
    }
    // Só pode desligar se há mais de 1 tela ativa
    return root.activeOutputCount > 1;
  }

  IpcHandler {
    target: "plugin:screen-manager"

    function toggle() {
      if (!root.pluginApi)
        return;

      root.pluginApi.withCurrentScreen(screen => {
        root.pluginApi.togglePanel(screen);
      });
    }

    function mirror() {
      root.refreshOutputs();
      Qt.callLater(() => {
        const main = root.getMainOutput();
        const secondary = root.getFirstSecondaryOutput();
        if (main && secondary) {
          root.startMirror(main, secondary);
          root.lastError = "";
        } else {
          root.lastError = root.pluginApi?.tr("main.error.needTwoMonitors");
        }
      });
    }

    function stopMirror() {
      root.stopMirror();
    }

    function disable() {
      root.refreshOutputs();
      Qt.callLater(() => {
        const secondary = root.getFirstSecondaryOutput();
        if (secondary) {
          if (!root.canDisable(secondary)) {
            root.lastError = root.pluginApi?.tr("main.error.lastScreenActive");
            return;
          }
          root.runDisableWithMove(secondary);
          root.lastError = "";
        } else {
          root.lastError = root.pluginApi?.tr("main.error.noSecondaryMonitor");
        }
      });
    }

    function refresh() {
      root.refreshOutputs();
    }
  }

  // Processo para executar comandos gerais (enable, etc.)
  Process {
    id: niriProcess
    running: false
    command: []

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        root.lastError = root.pluginApi?.tr("main.error.commandFailed").arg(exitCode);
      }
    }
  }

  // Processo para script helper (disable-with-move)
  Process {
    id: helperProcess
    running: false
    command: []

    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (output) {
          console.log("[ScreenManager]", output);
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.lastError = text.trim();
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        root.lastError = root.pluginApi?.tr("main.error.commandFailed").arg(exitCode);
      }
      // Refresh outputs after action completes
      root.refreshOutputs();
    }
  }

  // Processo para espelhamento (wl-mirror)
  Process {
    id: mirrorProcess
    running: false
    command: []

    onExited: (exitCode, exitStatus) => {
      root.mirrorSource = "";
      root.mirrorDestination = "";
      if (!root.mirrorStopRequested && exitCode !== 0 && exitStatus !== Process.NormalExit) {
        root.lastError = root.pluginApi?.tr("main.error.mirrorFailed").arg(exitCode);
      }
      root.mirrorStopRequested = false;
      root.refreshOutputs();
    }
  }

  // Processo para obter informações dos outputs
  Process {
    id: outputInfoProcess
    running: false
    command: ["niri", "msg", "-j", "outputs"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          const names = Object.keys(data);
          const outputsMap = {};

          for (let i = 0; i < names.length; i++) {
            const name = names[i];
            const raw = data[name];
            const modes = raw.modes || [];
            const modeIndex = raw.current_mode || 0;
            const currentMode = modes[modeIndex];
            const modeStr = currentMode
              ? currentMode.width + "x" + currentMode.height + "@" + (currentMode.refresh_rate / 1000).toFixed(1) + "Hz"
              : "Unknown";

            outputsMap[name] = {
              name: name,
              make: raw.make || "",
              model: raw.model || "",
              modes: modes,
              currentModeStr: modeStr,
              currentModeIndex: modeIndex,
              logical: raw.logical || null,
              isOn: raw.logical !== null && raw.logical !== undefined
            };
          }

          root.outputs = outputsMap;
          root.outputNames = names;
          root.outputCount = names.length;

          // Contar telas ativas (isOn === true)
          let activeCount = 0;
          for (let i = 0; i < names.length; i++) {
            if (outputsMap[names[i]].isOn) {
              activeCount++;
            }
          }
          root.activeOutputCount = activeCount;
        } catch (e) {
          root.lastError = "Parse error: " + e.toString();
        }
      }
    }
  }

  // Processo para obter output focado
  Process {
    id: focusedOutputProcess
    running: false
    command: ["niri", "msg", "-j", "focused-output"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          root.focusedOutput = data.name || "";
        } catch (e) {
          root.lastError = "Parse error: " + e.toString();
        }
      }
    }
  }

  function refreshOutputs() {
    outputInfoProcess.running = true;
    focusedOutputProcess.running = true;
  }

  function getMainOutput() {
    if (root.focusedOutput && root.outputs[root.focusedOutput]) {
      return root.focusedOutput;
    }
    return root.outputNames.length > 0 ? root.outputNames[0] : "";
  }

  function getFirstSecondaryOutput() {
    const main = getMainOutput();
    for (let i = 0; i < root.outputNames.length; i++) {
      if (root.outputNames[i] !== main) {
        return root.outputNames[i];
      }
    }
    return "";
  }

  function setOutputOn(outputName, turnOn) {
    // Trava de segurança: impedir desligar a última tela ativa
    if (!turnOn && !root.canDisable(outputName)) {
      root.lastError = root.pluginApi?.tr("main.error.lastScreenActive");
      return;
    }
    const action = turnOn ? "on" : "off";
    niriProcess.command = ["niri", "msg", "output", outputName, action];
    niriProcess.running = true;
  }

  function runDisableWithMove(outputName) {
    const scriptPath = root.pluginDir + "/screen-manager-actions.sh";
    helperProcess.command = ["bash", scriptPath, "disable-with-move", outputName];
    helperProcess.running = true;
  }

  function runMirror(source, destination) {
    const scriptPath = root.pluginDir + "/screen-manager-actions.sh";
    helperProcess.command = ["bash", scriptPath, "mirror", source, destination];
    helperProcess.running = true;
  }

  function startMirror(source, destination) {
    if (mirrorProcess.running) {
      root.lastError = root.pluginApi?.tr("main.error.alreadyMirroring");
      return;
    }
    if (source === destination) {
      root.lastError = root.pluginApi?.tr("main.error.sameMonitor");
      return;
    }
    root.lastError = "";
    root.mirrorSource = source;
    root.mirrorDestination = destination;
    mirrorProcess.command = ["wl-mirror", "--fullscreen-output", destination, source];
    mirrorProcess.running = true;
  }

  function stopMirror() {
    if (mirrorProcess.running) {
      root.mirrorStopRequested = true;
      mirrorProcess.signal(15);
    }
  }

  function enableAllOutputs() {
    const scriptPath = root.pluginDir + "/screen-manager-actions.sh";
    helperProcess.command = ["bash", scriptPath, "enable-all"];
    helperProcess.running = true;
  }

  function setOutputPosition(outputName, x, y) {
    niriProcess.command = ["niri", "msg", "output", outputName, "position", x + "," + y];
    niriProcess.running = true;
  }

  function setOutputMode(outputName, mode) {
    niriProcess.command = ["niri", "msg", "output", outputName, "mode", mode];
    niriProcess.running = true;
  }

  function setOutputScale(outputName, scale) {
    niriProcess.command = ["niri", "msg", "output", outputName, "scale", scale.toString()];
    niriProcess.running = true;
  }

  Component.onCompleted: {
    refreshOutputs();
    // Ao iniciar, ligar todas as telas conectadas
    Qt.callLater(() => {
      enableAllOutputs();
    });
  }
}