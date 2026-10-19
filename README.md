# Windows Server 2025 on a Contabo VPS

Install **Windows Server 2025** on your Contabo VPS with one script. No ISO uploads and no tricky setup: the script downloads everything for you.

> [!WARNING]
> This **deletes everything** on your VPS. Save anything you need before you start.

## What you need

- A Contabo VPS (at least 50 GB of disk)
- A VNC viewer, such as [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/) (free)
- About 30-45 minutes

## Step 1 - Start the Rescue System

1. Log in to the Contabo control panel.
2. Find your VPS and click **Manage → Rescue System**.
3. Choose the newest **Debian** version, set a password and start it.
4. Wait about a minute.

## Step 2 - Run the script

Open a terminal (on Windows: **PowerShell**) and connect to your VPS. Replace `YOUR_VPS_IP` with your VPS IP address:

```sh
ssh root@YOUR_VPS_IP
```

Type `yes` if asked, then the password from Step 1 (it stays invisible while you type).

Now copy and paste these two lines:

```sh
wget https://raw.githubusercontent.com/Rustyyyh/contabo-windows-server-2025/main/install.sh
bash install.sh
```

When asked, type `YES` and press Enter. Then wait: it takes 15-30 minutes.

When it says **Ready**, write down the IP address and gateway it shows, then press Enter. The VPS restarts.

## Step 3 - Install Windows

1. In the Contabo panel, click **Manage → VNC Information** to see the VNC address and set a VNC password.
2. Connect with your VNC viewer. You will see the Windows installer.
3. Choose your language and click **Install**.
4. When asked for a driver:
   - click **Browse**, choose `X:\virtio` and click **OK**;
   - select **all** the drivers in the list and click **Install**.
5. Choose **Windows Server 2025 Standard Evaluation (Desktop Experience)**.
6. Choose **Unallocated Space** and click **Next**.
7. Wait for the installation, then choose a password for **Administrator**.

## Step 4 - Connect to your server

On your Windows PC, open **Remote Desktop Connection**, type your VPS IP and log in as `Administrator` with the password you just chose.

That's it. Enjoy your Windows Server.

## Something went wrong?

**The screen says "Press Ctrl+Alt+Delete" and nothing happens**
Your own PC catches that key combination. In RealVNC, press **F8** inside the VNC window and choose **Send Ctrl+Alt+Del** (or use the button in the top toolbar).

**The mouse pointer does not follow your mouse in VNC**
Press **Win+R**, type `main.cpl` and press Enter. In **Pointer Options**, uncheck **Enhance pointer precision** and click OK. Then move the mouse to the top-left corner to realign it.

**There is no `X:\virtio` folder, or you get error `0x80070103`**
Start the Rescue System again (Step 1), connect (Step 2) and run:
```sh
wget https://raw.githubusercontent.com/Rustyyyh/contabo-windows-server-2025/main/install.sh
bash install.sh --repair-drivers
```
Nothing is deleted. The VPS restarts and you can continue from Step 3.

**Remote Desktop does not connect**
Open the VNC console, go to **Settings → System → Remote Desktop** and turn it on.

**No internet in Windows**
The network is set up automatically, but if it does not work, set it by hand. Open the VNC console, open **Terminal**, type `sconfig` and press Enter. Then type `8`, the number of your network adapter, and:
- `1`, then `S`, then the IP address, subnet mask `255.255.255.0` and the gateway you wrote down in Step 2;
- `2`, then DNS servers `1.1.1.1` and `8.8.8.8`.

## Good to know

- This is the free **evaluation** version of Windows Server, valid for **180 days**. To keep using it, activate it with your own license key.
- About 14 GB of the disk is kept for the Windows startup files.
- Use it at your own risk.

## License

[MIT](LICENSE)
