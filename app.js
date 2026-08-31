(() => {
  "use strict";

  const USB_FILTER = { vendorId: 0x2e3c, productId: 0xdf11 };
  const FLASH_BASE = 0x08000000;
  const DEFAULT_TRANSFER_SIZE = 2048;
  const MASS_ERASE_COMMAND = 0x41;
  const RECONNECT_TIMEOUT_MS = 20000;
  const FIRMWARE_MANIFEST_URL = "firmware/manifest.json";

  let device = null;
  let selectedFile = null;
  let latestFirmware = null;
  let transferSize = DEFAULT_TRANSFER_SIZE;
  let operationInProgress = false;
  let expectedDisconnect = false;

  const connectButton = document.querySelector("#connectButton");
  const flashButton = document.querySelector("#flashButton");
  const firmwareFile = document.querySelector("#firmwareFile");
  const latestFirmwareButton = document.querySelector("#latestFirmwareButton");
  const latestFirmwareStatus = document.querySelector("#latestFirmwareStatus");
  const clearFileButton = document.querySelector("#clearFileButton");
  const clearConsoleButton = document.querySelector("#clearConsoleButton");
  const statusConsole = document.querySelector("#statusConsole");
  const connectionState = document.querySelector("#connectionState");
  const stateDot = document.querySelector("#stateDot");
  const deviceDetails = document.querySelector("#deviceDetails");
  const deviceName = document.querySelector("#deviceName");
  const interfaceName = document.querySelector("#interfaceName");
  const transferSizeLabel = document.querySelector("#transferSize");
  const fileRow = document.querySelector("#fileRow");
  const fileName = document.querySelector("#fileName");
  const fileSize = document.querySelector("#fileSize");
  const progressBar = document.querySelector("#progressBar");
  const progressStage = document.querySelector("#progressStage");
  const progressValue = document.querySelector("#progressValue");

  function formatError(error) {
    if (typeof error === "string") return error;
    return error?.message || String(error);
  }

  function log(message, level = "INFO") {
    const timestamp = new Date().toLocaleTimeString([], { hour12: false });
    statusConsole.value += `[${timestamp}] ${level.padEnd(5)} ${message}\n`;
    statusConsole.scrollTop = statusConsole.scrollHeight;
  }

  function setConnectionState(label, mode = "idle") {
    connectionState.textContent = label;
    stateDot.classList.toggle("connected", mode === "connected");
    stateDot.classList.toggle("busy", mode === "busy");
  }

  function setProgress(stage, percent) {
    const bounded = Math.max(0, Math.min(100, Math.round(percent)));
    progressStage.textContent = stage;
    progressValue.textContent = `${bounded}%`;
    progressBar.value = bounded;
    progressBar.textContent = `${bounded}%`;
  }

  function updateControls() {
    const connected = Boolean(device?.device_?.opened);
    connectButton.disabled = operationInProgress;
    connectButton.querySelector("span").textContent = connected ? "Disconnect" : "Connect Sleepus MK3";
    firmwareFile.disabled = operationInProgress;
    latestFirmwareButton.disabled = operationInProgress;
    clearFileButton.disabled = operationInProgress;
    flashButton.disabled = !connected || !selectedFile || operationInProgress;
  }

  async function sha256Hex(data) {
    const digest = await crypto.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
  }

  function selectFirmware(file, detail) {
    selectedFile = file;
    fileName.textContent = file.name;
    fileSize.textContent = detail || `${file.size.toLocaleString()} bytes`;
    fileRow.hidden = false;
    updateControls();
  }

  async function discoverLatestFirmware() {
    try {
      const response = await fetch(FIRMWARE_MANIFEST_URL, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const manifest = await response.json();
      if (!manifest.version || !manifest.file || !manifest.sha256 || !Number.isFinite(manifest.size)) {
        throw new Error("Invalid firmware manifest");
      }
      latestFirmware = manifest;
      latestFirmwareStatus.textContent = `Latest release: ${manifest.version} / ${manifest.size.toLocaleString()} bytes`;
      latestFirmwareButton.hidden = false;
    } catch (error) {
      latestFirmwareStatus.textContent = "No published release yet. Choose a local .bin file.";
      log(`Latest firmware unavailable: ${formatError(error)}`, "WARN");
    }
  }

  async function selectLatestFirmware() {
    if (!latestFirmware) return;
    latestFirmwareButton.disabled = true;
    latestFirmwareStatus.textContent = `Downloading ${latestFirmware.version}...`;
    try {
      const firmwareUrl = new URL(`firmware/${encodeURIComponent(latestFirmware.file)}`, location.href);
      const response = await fetch(firmwareUrl, { cache: "no-store" });
      if (!response.ok) throw new Error(`Firmware download failed with HTTP ${response.status}.`);
      const data = await response.arrayBuffer();
      if (data.byteLength !== latestFirmware.size) throw new Error("Downloaded firmware size does not match its manifest.");
      const digest = await sha256Hex(data);
      if (digest !== latestFirmware.sha256.toLowerCase()) throw new Error("Downloaded firmware failed SHA-256 verification.");

      const file = new File([data], latestFirmware.file, { type: "application/octet-stream" });
      selectFirmware(file, `${latestFirmware.version} / ${file.size.toLocaleString()} bytes / SHA-256 verified`);
      latestFirmwareStatus.textContent = `Latest release: ${latestFirmware.version} / verified`;
      log(`Selected and verified published firmware ${latestFirmware.version}.`);
    } catch (error) {
      latestFirmwareStatus.textContent = `Could not load ${latestFirmware.version}.`;
      log(formatError(error), "ERROR");
    } finally {
      latestFirmwareButton.disabled = false;
    }
  }

  function clearDeviceState(reason = "Not connected") {
    device = null;
    deviceDetails.hidden = true;
    setConnectionState(reason);
    updateControls();
  }

  function bindDeviceLogging(activeDevice) {
    activeDevice.logDebug = message => log(message, "DEBUG");
    activeDevice.logInfo = message => log(message);
    activeDevice.logWarning = message => log(message, "WARN");
    activeDevice.logError = message => log(message, "ERROR");
    activeDevice.logProgress = (done, total) => {
      if (Number.isFinite(total) && total > 0) {
        setProgress("Writing firmware", 25 + (done / total) * 70);
      }
    };
  }

  async function readDfuProperties(activeDevice) {
    try {
      const raw = await activeDevice.readConfigurationDescriptor(0);
      const descriptor = dfu.parseConfigurationDescriptor(raw).descriptors.find(
        item => item.bDescriptorType === 0x21 && Object.prototype.hasOwnProperty.call(item, "wTransferSize")
      );
      return descriptor || null;
    } catch (error) {
      log(`Could not read DFU functional descriptor: ${formatError(error)}`, "WARN");
      return null;
    }
  }

  async function openSelectedDevice(usbDevice) {
    const interfaces = dfu.findDeviceDfuInterfaces(usbDevice).filter(
      settings => settings.alternate.interfaceProtocol === 0x02
    );
    if (!interfaces.length) throw new Error("The selected device has no DFU-mode interface.");

    const settings = interfaces.find(item => item.name?.startsWith("@")) || interfaces[0];
    let activeDevice = new dfu.Device(usbDevice, settings);
    try {
      await activeDevice.open();
    } catch (error) {
      try { await usbDevice.close(); } catch (_) { /* Opening may have failed before the device was claimed. */ }
      throw error;
    }

    const properties = await readDfuProperties(activeDevice);
    transferSize = properties?.wTransferSize || DEFAULT_TRANSFER_SIZE;
    if (properties && (properties.bmAttributes & 0x01) === 0) {
      await activeDevice.close();
      throw new Error("This DFU interface does not support firmware downloads.");
    }

    if (properties?.bcdDFUVersion === 0x011a || settings.name?.startsWith("@")) {
      activeDevice = new dfuse.Device(usbDevice, settings);
    } else {
      await activeDevice.close();
      throw new Error("The bootloader does not expose a DfuSe memory interface.");
    }

    activeDevice.startAddress = FLASH_BASE;
    bindDeviceLogging(activeDevice);
    device = activeDevice;

    deviceName.textContent = usbDevice.productName || "AT32 DFU Bootloader";
    interfaceName.textContent = settings.name || `Interface ${activeDevice.intfNumber}`;
    transferSizeLabel.textContent = `${transferSize} bytes`;
    deviceDetails.hidden = false;
    setConnectionState("DFU device connected", "connected");
    log(`Connected to ${deviceName.textContent} [2E3C:DF11].`);
    log(`Flash target 0x${FLASH_BASE.toString(16).padStart(8, "0").toUpperCase()}; transfer size ${transferSize} bytes.`);
    updateControls();
  }

  async function connectWithPrompt() {
    if (!navigator.usb) throw new Error("WebUSB is unavailable. Use current Chrome or Edge over HTTPS.");

    const authorizedDevices = await navigator.usb.getDevices();
    const authorizedDevice = authorizedDevices.find(candidate =>
      candidate.vendorId === USB_FILTER.vendorId && candidate.productId === USB_FILTER.productId
    );
    if (authorizedDevice) {
      log("Reconnecting to the previously approved Sleepus MK3.");
      try {
        await openSelectedDevice(authorizedDevice);
        return;
      } catch (error) {
        log(`Automatic reconnect failed: ${formatError(error)}. Opening Chrome's device window instead.`, "WARN");
      }
    }

    log("In Chrome's device window, select 'DFU in FS Mode - Paired', then click Connect.");
    const usbDevice = await navigator.usb.requestDevice({ filters: [USB_FILTER] });
    await openSelectedDevice(usbDevice);
  }

  async function disconnect() {
    if (device) await device.close();
    clearDeviceState();
    log("Device disconnected.");
  }

  async function ensureIdle(activeDevice) {
    const status = await activeDevice.getStatus();
    if (status.state === dfu.dfuERROR) {
      await activeDevice.clearStatus();
    } else if (status.state !== dfu.dfuIDLE) {
      await activeDevice.abortToIdle();
    }
  }

  function isDisconnectError(error) {
    return /disconnected|device unavailable|notfounderror|unable to claim|transfer failed/i.test(formatError(error));
  }

  async function massErase(activeDevice) {
    await ensureIdle(activeDevice);
    log("Issuing DfuSe full-chip mass erase (0x41).", "WARN");
    setProgress("Mass erasing flash", 8);

    await activeDevice.download(Uint8Array.of(MASS_ERASE_COMMAND).buffer, 0);
    try {
      const status = await activeDevice.poll_until(state => state !== dfu.dfuDNBUSY && state !== dfu.dfuDNLOAD_SYNC);
      if (status.status !== dfu.STATUS_OK) {
        throw new Error(`Mass erase failed with DFU status ${status.status}.`);
      }
      await ensureIdle(activeDevice);
      setProgress("Mass erase complete", 25);
      log("Mass erase complete. Read protection is cleared.");
      return false;
    } catch (error) {
      if (!isDisconnectError(error)) throw error;
      expectedDisconnect = true;
      log("Bootloader reset after removing read protection; waiting for DFU to return.", "WARN");
      return true;
    }
  }

  async function writeFirmware(activeDevice, image) {
    let bytesSent = 0;
    let address = FLASH_BASE;

    while (bytesSent < image.byteLength) {
      const chunkSize = Math.min(transferSize, image.byteLength - bytesSent);
      await activeDevice.dfuseCommand(dfuse.SET_ADDRESS, address, 4);
      const bytesWritten = await activeDevice.download(image.slice(bytesSent, bytesSent + chunkSize), 2);
      const status = await activeDevice.poll_until_idle(dfu.dfuDNLOAD_IDLE);
      if (status.status !== dfu.STATUS_OK) {
        throw new Error(`Firmware write failed at 0x${address.toString(16)} with DFU status ${status.status}.`);
      }
      if (bytesWritten !== chunkSize) {
        throw new Error(`Short firmware write at 0x${address.toString(16)}: ${bytesWritten} of ${chunkSize} bytes.`);
      }

      bytesSent += bytesWritten;
      address += bytesWritten;
      setProgress("Writing firmware", 25 + (bytesSent / image.byteLength) * 70);
    }

    log(`Wrote ${bytesSent.toLocaleString()} bytes. Manifesting firmware.`);
    await activeDevice.dfuseCommand(dfuse.SET_ADDRESS, FLASH_BASE, 4);
    await activeDevice.download(new ArrayBuffer(), 0);
    try {
      const status = await activeDevice.poll_until(state =>
        state === dfu.dfuMANIFEST || state === dfu.dfuMANIFEST_WAIT_RESET || state === dfu.dfuIDLE
      );
      if (status.status !== dfu.STATUS_OK) {
        throw new Error(`Firmware manifestation failed with DFU status ${status.status}.`);
      }
    } catch (error) {
      if (!isDisconnectError(error)) throw error;
      log("Device reset after firmware manifestation.");
    }
  }

  async function waitForReconnect(previousUsbDevice) {
    try { await previousUsbDevice.close(); } catch (_) { /* Device may already be gone. */ }
    device = null;
    setConnectionState("Waiting for bootloader", "busy");
    updateControls();

    const deadline = Date.now() + RECONNECT_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const devices = await navigator.usb.getDevices();
      const match = devices.find(candidate =>
        candidate.vendorId === USB_FILTER.vendorId && candidate.productId === USB_FILTER.productId
      );
      if (match) {
        try {
          await openSelectedDevice(match);
          expectedDisconnect = false;
          log("DFU bootloader reconnected after mass erase.");
          return;
        } catch (_) {
          // Enumeration or driver claim may not be ready yet.
        }
      }
      await new Promise(resolve => setTimeout(resolve, 500));
    }
    throw new Error("The bootloader did not reconnect. Keep BOOT0 held, reconnect USB, then press Connect Device and Flash Firmware again.");
  }

  async function flashFirmware() {
    if (!device || !selectedFile) return;
    operationInProgress = true;
    updateControls();
    setConnectionState("Updating firmware", "busy");
    setProgress("Reading firmware", 2);

    try {
      const image = await selectedFile.arrayBuffer();
      if (!image.byteLength) throw new Error("The selected firmware file is empty.");
      log(`Starting update with ${selectedFile.name} (${image.byteLength.toLocaleString()} bytes).`);

      const beforeErase = device.device_;
      const disconnected = await massErase(device);
      if (disconnected) await waitForReconnect(beforeErase);

      await ensureIdle(device);
      device.startAddress = FLASH_BASE;
      log("Writing firmware at 0x08000000.");
      setProgress("Writing firmware", 25);
      await writeFirmware(device, image);
      setProgress("Update complete", 100);
      log("Firmware update complete. The device may now restart.");
      setConnectionState("Update complete", "connected");
    } catch (error) {
      const message = formatError(error);
      log(message, "ERROR");
      setProgress("Update failed", 0);
      setConnectionState(device?.device_?.opened ? "Update failed" : "Not connected");
    } finally {
      operationInProgress = false;
      updateControls();
    }
  }

  connectButton.addEventListener("click", async () => {
    try {
      if (device?.device_?.opened) {
        await disconnect();
      } else {
        setConnectionState("Connecting", "busy");
        await connectWithPrompt();
      }
    } catch (error) {
      log(formatError(error), "ERROR");
      clearDeviceState();
    }
  });

  firmwareFile.addEventListener("change", () => {
    const file = firmwareFile.files[0];
    if (!file) return;
    if (!file.name.toLowerCase().endsWith(".bin")) {
      log("Select a raw .bin firmware file.", "ERROR");
      firmwareFile.value = "";
      return;
    }
    selectFirmware(file);
    log(`Selected firmware: ${file.name}.`);
  });

  clearFileButton.addEventListener("click", () => {
    selectedFile = null;
    firmwareFile.value = "";
    fileRow.hidden = true;
    updateControls();
  });

  flashButton.addEventListener("click", flashFirmware);
  latestFirmwareButton.addEventListener("click", selectLatestFirmware);
  clearConsoleButton.addEventListener("click", () => { statusConsole.value = ""; });

  if (navigator.usb) {
    navigator.usb.addEventListener("disconnect", event => {
      if (device?.device_ === event.device) {
        if (!expectedDisconnect) log("USB device disconnected.", "WARN");
        device = null;
        if (!operationInProgress) clearDeviceState();
      }
    });
  } else {
    connectButton.disabled = true;
    setConnectionState("WebUSB unavailable");
  }

  if (window.lucide) window.lucide.createIcons();
  log("Updater ready. Enter BOOT0 mode, then connect the device.");
  updateControls();
  discoverLatestFirmware();
})();
