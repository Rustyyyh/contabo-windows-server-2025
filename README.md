# Windows Server 2025 on a Contabo VPS

A single script that installs **Windows Server 2025** on a Contabo VPS, starting from the Contabo **Rescue System**.

The script prepares the disk, downloads the official Windows Server 2025 ISO from Microsoft and the VirtIO drivers from the Fedora project, and makes the server boot into Windows Setup. You then finish the installation from the VNC console.

> [!WARNING]
> The script **erases the entire disk** of the VPS. Back up anything you need first.

## Requirements

- A Contabo VPS with at least 50 GB of disk (BIOS boot, which is the default on Contabo VPS)
- A VNC viewer, for example [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/)
- An SSH client (built into Windows 10/11, macOS and Linux)
- A Remote Desktop client (built into Windows: `mstsc`)

## 1. Start the Rescue System

In the Contabo control panel:

1. Open your VPS, then **Manage → Rescue System**.
2. Pick the latest **Debian** rescue image and set a root password.
3. Start the Rescue System and wait a minute.

## 2. Run the script

Connect over SSH with the rescue password:

```sh
ssh root@YOUR_VPS_IP
```

Then download and run the script:

```sh
wget https://raw.githubusercontent.com/Rustyyyh/contabo-windows-server-2025/main/install.sh
bash install.sh
```

The script shows the disk and asks you to type `YES` before changing anything. The full run takes 15 to 30 minutes, mostly for the download. At the end it shows your **IP address and gateway**: write them down, then press Enter to reboot.

## 3. Install Windows over VNC

Get the VNC address and port from **Manage → VNC Information** in the control panel, set a VNC password if you have not done it yet, and connect.

1. If asked, press any key to start Setup.
2. Choose language and keyboard, then **Install**.
3. On **Install driver to show hardware**:
   - click **Browse**, select `X:\virtio` and click **OK**;
   - select **all** the drivers in the list (VirtIO SCSI and VirtIO Ethernet) and click **Install**.
4. Choose **Windows Server 2025 Standard (Desktop Experience)**.
5. Select **Unallocated Space** and click **Next**.
6. When Setup finishes, set the **Administrator** password.

## 4. Connect with Remote Desktop

Remote Desktop is enabled automatically at the end of Setup. Connect to your VPS IP with the user `Administrator`:

```sh
mstsc /v:YOUR_VPS_IP
```

## Troubleshooting

| Problem | Solution |
|---|---|
| `X:\virtio` does not exist in Setup | Boot the Rescue System again and run `bash install.sh --repair-drivers`. It rebuilds the drivers without erasing anything. |
| The driver list is empty | Uncheck **Hide drivers that aren't compatible** and check that `X:\virtio\vioscsi` is selected. |
| Error `0x80070103 - 0x40031` | Drivers were auto-loaded by an older version of this script. Run `bash install.sh --repair-drivers` from the Rescue System. |
| No network in Windows | Set a static IP with the values shown by the script (IP, gateway, mask `255.255.255.0`, DNS `1.1.1.1`). |
| Remote Desktop does not connect | From VNC: **Settings → System → Remote Desktop → On**. |
| `the server booted in UEFI mode` | This VPS uses UEFI boot, which the script does not support. |

## How it works

```
Disk (MBR)
├── Partition 1  NTFS  14 GiB   Windows installer files + GRUB, active
│                               (after Setup it holds the Windows boot files)
└── Unallocated  rest of disk   Windows is installed here
```

1. The disk is split into a 14 GiB installer partition and a temporary partition for the downloads.
2. The Windows ISO is copied to the installer partition, and GRUB is installed to start the Windows boot manager from it.
3. The VirtIO disk and network drivers are added to the Setup environment (`boot.wim`) as `X:\virtio`. The full driver set is kept in `virtio-drivers` on the installer partition.
4. A `SetupComplete.cmd` script enables Remote Desktop and its firewall rule.
5. The temporary partition is deleted, so Setup sees the free space as **Unallocated Space**.

The installer partition (14 GiB) stays on the disk because Windows boots from it. You can give it a drive letter in Disk Management and delete everything except `bootmgr` and the `Boot` folder to reuse the space.

## Licensing

The ISO is the official **Windows Server 2025 Evaluation**, valid for 180 days. To keep using Windows Server, convert it to a licensed edition with your own product key:

```
DISM /Online /Set-Edition:ServerStandard /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula
```

You are responsible for licensing Windows correctly. Use this script at your own risk.

## License

[MIT](LICENSE)
